# Plan: MCP OAuth Authentication

## Context

The MCP server is live at `/mcp` with JWT auth via `McpJwtGuard`. Currently, users must obtain a Projulous JWT through the web/mobile login flow and manually configure it as a Bearer token. This is impractical for MCP clients like Claude Code and Cursor, which expect OAuth 2.0 discovery + authorization code flow with PKCE.

`@rekog/mcp-nest` includes `McpAuthModule` — a complete OAuth 2.0 Authorization Server with PKCE, client registration, token refresh, and RFC 8414/9728 metadata discovery. We'll use it for browser-based OAuth login, add API key support for server-to-server use, and keep existing Projulous JWT auth working unchanged.

---

## Phase 1a: Google OAuth via McpAuthModule — COMPLETE

### What Changes

1. **Add `McpAuthModule.forRoot()`** to `ProjulousMcpModule` — enables OAuth endpoints at `/mcp/authorize`, `/mcp/callback`, `/mcp/token`, `/mcp/register`, `/mcp/revoke`, plus `.well-known/*` metadata
2. **Update `McpJwtGuard`** to handle 3 auth methods: Projulous JWT, MCP OAuth JWT, and API keys (Phase 1b)
3. **Add `getUserContextIds()`** to `AuthService` — resolves customerId/serviceProviderId without generating tokens

### McpAuthModule Configuration

**File to modify**: `src/mcp/mcp.module.ts`

```typescript
import { McpAuthModule, GoogleOAuthProvider } from '@rekog/mcp-nest';

// Add to imports array:
McpAuthModule.forRoot({
  provider: GoogleOAuthProvider,
  clientId: cfg.oauthGoogle.clientId,
  clientSecret: cfg.oauthGoogle.clientSecret,
  jwtSecret: cfg.auth.jwtSecret,          // Same secret → guard verifies both token types
  serverUrl: cfg.runtime.isLocal
    ? `http://localhost:${cfg.runtime.appPort}`
    : 'https://api.projulous.com',
  resource: cfg.runtime.isLocal
    ? `http://localhost:${cfg.runtime.appPort}/mcp`
    : 'https://api.projulous.com/mcp',
  jwtAccessTokenExpiresIn: '1d',
  jwtRefreshTokenExpiresIn: '30d',
  enableRefreshTokens: true,
  apiPrefix: 'mcp',                       // Endpoints at /mcp/authorize, /mcp/token, etc.
}),
```

**Key**: Using the same `jwtSecret` as Projulous means `jwt.verify()` validates both token types. The guard distinguishes them by payload shape.

### Guard Dual-Token Logic

**File to modify**: `src/mcp/guards/mcpJwt.guard.ts`

Token type detection by payload shape:
- **Projulous JWT**: has `tokenVersion` field → existing flow (validate version, hydrate permissions)
- **MCP OAuth JWT**: has `type: 'access'` field → bridge flow:
  1. Extract email from `payload.user_data.email` (Google profile data embedded by McpAuthModule)
  2. `UserService.getUserByUserName(email)` — find Projulous user by `emailOrUserName`
  3. `AuthService.getUserPermissionsList(userId)` — hydrate permissions
  4. `AuthService.getUserContextIds(userId)` — resolve customerId + serviceProviderId
- **API Key** (Phase 1b): starts with `pjx_` prefix → hash validation

All services resolved via `ModuleRef.get(X, { strict: false })` (proven pattern from current guard).

### New AuthService Helper

**File to modify**: `src/auth/services/auth.service.ts`

```typescript
async getUserContextIds(userId: string): Promise<{ customerId?: string; serviceProviderId?: string }> {
  const [customerResult, serviceProviderId] = await Promise.all([
    this.customerRepoRead.findOne({ where: { user: { userId } } }),
    this.getServiceProviderIdForUser(userId),   // existing private method at line 457
  ]);
  return { customerId: customerResult?.customerId, serviceProviderId };
}
```

Reuses existing `getServiceProviderIdForUser()` and the customer query pattern from `getTokensForUser()` (line 664).

### Google Console Prerequisite

Register new authorized redirect URIs:
- Local: `http://localhost:8123/mcp/callback`
- Prod: `https://api.projulous.com/mcp/callback`

### Bug Fix: cookie-parser middleware

The `@rekog/mcp-nest` OAuth controller reads `req.cookies.oauth_session` to track the OAuth session between `/mcp/authorize` and `/mcp/callback`. Without `cookie-parser` middleware, `req.cookies` is undefined, causing "Missing OAuth session" errors. Fixed by installing `cookie-parser` and adding `app.use(cookieParser())` in `main.ts`.

### Files Summary (Phase 1a)

| File | Change |
|------|--------|
| `src/mcp/mcp.module.ts` | Add `McpAuthModule.forRoot()` import with Google config |
| `src/mcp/guards/mcpJwt.guard.ts` | Dual-token handling + UserService lazy resolution |
| `src/auth/services/auth.service.ts` | Add `getUserContextIds()` method |
| `src/main.ts` | Add `cookie-parser` middleware for OAuth session cookies |

---

## Phase 1b: API Keys — COMPLETE

### Design

- Format: `pjx_<32-byte-base64url>` (~43 chars total)
- Storage: argon2 hash in PostgreSQL, `keyPrefix` (first 8 chars) indexed for fast lookup
- Management: REST endpoints behind existing Projulous JWT auth

### New Entity

**File to create**: `projulous-shared-dto-node/mcp/mcpApiKey.entity.ts`

Fields: `mcpApiKeyId` (PK/UUID), `keyPrefix` (varchar 8, indexed where active), `keyHash` (argon2), `user` (FK→User), `name` (varchar 100), `lastUsedAt`, `expiresAt`, `isActive` (default true), timestamps, `standardFields`

### New Service

**File to create**: `src/mcp/services/mcpApiKey.service.ts`

- `createKey(user, name, expiresInDays?)` → generates raw key, stores argon2 hash, returns key once
- `listKeys(user)` → returns metadata (never hashes)
- `revokeKey(user, mcpApiKeyId)` → sets `isActive = false`
- `validateKey(rawKey)` → prefix lookup → argon2 verify → returns User

### New Controller

**File to create**: `src/mcp/controllers/mcpApiKey.controller.ts`

- `POST /v1/mcp/api-keys` — create (returns raw key once)
- `GET /v1/mcp/api-keys` — list user's keys
- `DELETE /v1/mcp/api-keys/:id` — revoke

Protected by `AuthGuard('jwt')` + `PermissionsRESTGuard`. New permissions: `MCP_API_KEY_CREATE`, `MCP_API_KEY_READ`, `MCP_API_KEY_DELETE`.

### Guard Update

Add to `McpJwtGuard.canActivate()` before JWT verification:
```typescript
if (token.startsWith('pjx_')) {
  return this.handleApiKey(token, request);  // validates hash, hydrates UserAuthModel
}
```

### Web UI — COMPLETE

**Files created:**
- `projulous-web/app/dataAccess/mcp/mcpApiKey.da.tsx` — REST data access class
- `projulous-web/app/routes/auth/mcpApiKeySettings.component.tsx` — API key management UI component

**Files modified:**
- `projulous-web/app/routes/auth/settings.route.tsx` — Added API Keys section
- `projulous-web/public/translations/en.json` — English translations (settings.apiKeys)
- `projulous-web/public/translations/es.json` — Spanish translations
- `projulous-web/public/translations/fr.json` — French translations

### Files Summary (Phase 1b)

**Create:**
| File | Purpose |
|------|---------|
| `projulous-shared-dto-node/mcp/mcpApiKey.entity.ts` | Entity + DTO |
| `projulous-shared-dto-node/mcp/index.ts` | Barrel export |
| `src/mcp/services/mcpApiKey.service.ts` | CRUD + hash validation |
| `src/mcp/controllers/mcpApiKey.controller.ts` | REST endpoints |
| `projulous-web/app/dataAccess/mcp/mcpApiKey.da.tsx` | Web data access |
| `projulous-web/app/routes/auth/mcpApiKeySettings.component.tsx` | Settings UI |

**Modify:**
| File | Change |
|------|--------|
| `src/mcp/mcp.module.ts` | Add service, controller, TypeOrmModule.forFeature |
| `src/mcp/guards/mcpJwt.guard.ts` | Add `pjx_` prefix detection |
| `src/app.module.ts` | Add `McpApiKey` to entity arrays |
| `projulous-web/app/routes/auth/settings.route.tsx` | Add McpApiKeySettings component |
| `projulous-web/public/translations/*.json` | i18n strings (EN/ES/FR) |

**Migration**: `npm run migration:generate -- src/migrations/AddMcpApiKeysTable`

---

## Phase 2: Multi-Provider (Apple + Facebook) — DEFERRED

`McpAuthModule` accepts one provider per `forRoot()`. For multi-provider:

**Recommended**: Custom provider picker page. `/mcp/authorize` redirects to `https://projulous.com/mcp/auth-picker?session=<id>`. Frontend shows "Sign in with Google / Apple / Facebook". User picks one, backend initiates that provider's OAuth via existing Passport strategies, then redirects back through the McpAuthModule callback. Single set of `.well-known` endpoints, works with all MCP clients.

Deferred until Phase 1 is stable.

---

## Implementation Order

1. ~~Phase 1a Step 1: Add `McpAuthModule.forRoot()` to `mcp.module.ts`~~ DONE
2. ~~Phase 1a Step 2: Add `getUserContextIds()` to `AuthService`~~ DONE
3. ~~Phase 1a Step 3: Update `McpJwtGuard` for dual-token handling~~ DONE
4. ~~Phase 1a Step 4: Register Google redirect URIs (manual — user action)~~ DONE
5. ~~Phase 1a Step 5: Build + verify OAuth flow end-to-end~~ DONE
6. ~~Phase 1a Step 6: Add `cookie-parser` middleware for OAuth session cookies~~ DONE
7. ~~Phase 1b Steps 1-4: API key entity, service, controller, migration, permissions~~ DONE
8. ~~Phase 1b Step 5: Build + verify API keys end-to-end~~ DONE
9. ~~Phase 1b Step 6: Web UI for API key management (settings page)~~ DONE
10. Phase 2: Multi-provider OAuth (Apple + Facebook) — DEFERRED

---

## Verification

### Phase 1a — VERIFIED
1. `npm run start:dev` — no errors
2. `GET http://localhost:8123/.well-known/oauth-authorization-server` → metadata JSON
3. `POST http://localhost:8123/mcp/register` → register test client
4. Full PKCE flow: `/mcp/authorize` → Google login → code → `/mcp/token` → access_token
5. MCP OAuth token works with tools (`Authorization: Bearer <mcp-token>`)
6. Existing Projulous JWT still works (backward compat)

### Phase 1b — VERIFIED
1. `POST /v1/mcp/api-keys` with Projulous JWT → returns raw key
2. `Authorization: Bearer pjx_...` against MCP tools → works
3. `DELETE /v1/mcp/api-keys/:id` → subsequent use returns 401
4. Web UI: create, view, copy, and revoke keys from settings page

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Guard DI scope: McpJwtGuard runs inside McpModule's internal scope | `ModuleRef.get(X, { strict: false })` for lazy resolution — proven working |
| Shared JWT secret token confusion | Guard checks payload shape (`tokenVersion` vs `type: 'access'`) |
| Google redirect URI mismatch | Must register `/mcp/callback` in Google Cloud Console before testing |
| MCP OAuth user has no Projulous account | Phase 1a: require existing account. Phase 2: auto-create via `findOrCreateSocialUser` |
| Passport strategy name collision | McpAuthModule registers with unique name (`oauth-provider-mcp-auth-module-0`), separate from existing `google` strategy |
| Missing cookie-parser | Fixed: `cookie-parser` installed and configured in `main.ts` |
| In-memory OAuth session store | Default MemoryStore works for single-instance. For multi-instance, switch to TypeORM store via `storeConfiguration` |
