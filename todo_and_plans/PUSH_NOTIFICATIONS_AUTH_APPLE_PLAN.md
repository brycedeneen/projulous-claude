# Push Notifications, Multi-Session Auth & Apple Login Plan

## Context

The mobile app is fully wired to **receive** push notifications (expo-notifications, token registration, foreground/background handlers, inbox UI, preferences) but the backend **never sends** them. Push tokens are stored in the DB and never used.

Additionally, the refresh token rotation scheme uses a single `User.refreshTokenHash`, which causes false "token theft" detection when multiple devices (web + mobile) refresh concurrently, invalidating all sessions.

Apple Sign-In is 90% built (backend strategy, endpoints, code exchange, mobile OAuth via browser, web button stubbed) but needs credentials, a native iOS integration, and the web feature flag enabled.

---

## Phase 1: Backend Push Notification Sending

### 1A: Install expo-server-sdk & create PushNotificationService

**New file:** `projulous-svc/src/notification/services/pushNotification.service.ts`

- Install `expo-server-sdk` in projulous-svc
- Create service wrapping Expo Push API
- `sendPushNotification(userId, title, body, data?)`:
  - Look up user's PushToken records (read replica)
  - Check user's `pushEnabled` preference
  - Validate tokens with `Expo.isExpoPushToken()`
  - Chunk and send via `expo.sendPushNotificationsAsync()`
  - Schedule receipt checking after 15s via `setTimeout`
- `checkReceipts(ticketIds)`:
  - On `DeviceNotRegistered`: delete stale PushToken from DB
  - On other errors: log only, never throw

No env vars needed -- Expo Push API is free and unauthenticated for Expo push tokens.

### 1B: Integrate into NotificationService.createNotification()

**Modify:** `projulous-svc/src/notification/services/notification.service.ts`

After existing `save()` + RabbitMQ emit (~line 122), add fire-and-forget:

```typescript
this.pushNotificationService.sendPushNotification(userId, title, message, {
  notificationId: newRecord.notificationId, type, recordId, link,
}).catch(err => this.logger.warn(`Push failed: ${err.message}`));
```

Push failures never break notification creation.

### 1C: Update notification.module.ts

**Modify:** `projulous-svc/src/notification/notification.module.ts`

Add `PushNotificationService` to providers array.

### 1D: Push token cleanup on logout

**Modify:** `projulous-svc/src/notification/controllers/notification.controller.ts`
- Add `DELETE /v1/notifications/push-token` endpoint accepting `{ platform }` body

**Modify:** `projulous-svc/src/notification/services/notification.service.ts`
- Add `unregisterPushToken(user, platform)` method

**Modify:** `projulous-mobile/dataAccess/auth/auth.da.ts`
- Update `logOut()` to call `DELETE /v1/notifications/push-token` and `POST /v1/auth/logout` before clearing local tokens (both wrapped in try/catch, non-critical)

### 1E: Tests

**New file:** `projulous-svc/src/notification/services/pushNotification.service.spec.ts`
- Mock `expo-server-sdk`, verify batching, receipt handling, token cleanup, preference checking

**Modify:** `projulous-svc/src/notification/services/notification.service.spec.ts`
- Verify push is called fire-and-forget after save; push failure doesn't affect return

---

## Phase 2: Multi-Session Refresh Token Fix

### 2A: Create RefreshTokenSession entity in shared-dto

**New file:** `projulous-shared-dto-node/auth/refreshTokenSession.entity.ts`

```
Table: RefreshTokenSessions
- refreshTokenSessionId (UUID PK)
- refreshTokenHash (string, not null)
- platform (string: 'web' | 'ios' | 'android')
- deviceInfo (string, nullable -- User-Agent or device name)
- lastUsed (timestamp)
- expiresAt (timestamp -- 7 days from issuance)
- userId (FK to Users)
- standardFields
```

**Modify:** `projulous-shared-dto-node/auth/index.ts` -- export new entity

### 2B: Update auth.service.ts for per-session tokens

**Modify:** `projulous-svc/src/auth/services/auth.service.ts`

- `getTokens()` -- accept `platform` and optional `existingSessionId` params
  - On new login: INSERT new RefreshTokenSession row
  - On rotation: UPDATE existing session's hash, lastUsed, expiresAt
  - Keep writing `User.refreshTokenHash` too during transition period

- `refreshTokens()` -- query RefreshTokenSessions for matching hash instead of User.refreshTokenHash
  - Found: rotate that session (update hash)
  - Not found: token theft -- increment tokenVersion, delete ALL sessions
  - Expired: delete session, throw ForbiddenException

- `logout()` -- delete all RefreshTokenSession rows for user (full logout)

- `signIn()` -- accept optional `platform` param, forward to `getTokens()`

- OAuth flows (`findOrCreateSocialUser`, `getTokensForUser`) -- accept platform param

### 2C: Update auth.controller.ts

**Modify:** `projulous-svc/src/auth/controllers/auth.controller.ts`

- `POST /v1/login` -- accept `platform?` in body, forward to signIn()
- OAuth callbacks -- pass platform from query/state param

### 2D: Mobile login sends platform

**Modify:** `projulous-mobile/dataAccess/auth/auth.da.ts`

- Login POST body includes `platform: process.env.EXPO_OS === 'ios' ? 'ios' : 'android'`

### 2E: Session cleanup CRON

**New file:** `projulous-svc/src/auth/services/sessionCleanupCron.service.ts`

- Daily at 3 AM UTC (guarded by `ENABLE_CRON=true`)
- DELETE FROM RefreshTokenSessions WHERE expiresAt < NOW()

### 2F: Migration

1. Build & push projulous-shared-dto-node
2. `npm install projulous-shared-dto-node` in projulous-svc
3. Register RefreshTokenSession in app.module.ts + auth.module.ts
4. `npm run migration:generate -- src/migrations/AddRefreshTokenSessions`
5. Keep `User.refreshTokenHash` during transition -- drop later

### 2G: Tests

**Modify:** `projulous-svc/src/auth/services/auth.service.spec.ts`
- refreshTokens: rotate matching session without invalidating others
- refreshTokens: detect theft when no session matches
- logout: delete sessions
- getTokens: create vs update session

---

## Phase 3: Complete Apple Sign-In

### 3A: Apple Developer Setup (manual, not code)

Required from Apple Developer Account:
1. Create App ID with "Sign in with Apple" capability
2. Create Services ID (this is the `APPLE_CLIENT_ID`)
3. Configure domains + return URLs in Services ID
4. Create a Key for Sign in with Apple (provides `APPLE_KEY_ID` and `.p8` private key file)
5. Note your `APPLE_TEAM_ID`

### 3B: Configure backend env vars

**Modify:** `projulous-svc/prod.dev.env` and `projulous-svc/local.dev.env`

Replace placeholders with real values:
```
APPLE_CLIENT_ID=<services-id>
APPLE_TEAM_ID=<team-id>
APPLE_KEY_ID=<key-id>
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

### 3C: Native iOS Apple Sign-In on mobile

**Install:** `npx expo install expo-apple-authentication` in projulous-mobile

**Modify:** `projulous-mobile/app.json`
- Add `usesAppleSignIn: true` to iOS config (enables entitlement)

**New file:** `projulous-mobile/utils/appleAuth.ts`
- Wrapper around `expo-apple-authentication`:
  - Check `AppleAuthentication.isAvailableAsync()`
  - Call `AppleAuthentication.signInAsync()` with `FULL_NAME` + `EMAIL` scopes
  - Returns `{ identityToken, authorizationCode, fullName, email }`

**Modify:** `projulous-mobile/dataAccess/auth/auth.da.ts`
- Update `loginWithApple()`:
  - On iOS: use native `expo-apple-authentication` to get identity token
  - Send identity token to backend for verification (new endpoint, see 3D)
  - On Android: keep existing web browser OAuth flow (Apple doesn't support native on Android)

**Modify:** `projulous-mobile/app/(auth)/login.tsx`
- On iOS: use `AppleAuthentication.AppleAuthenticationButton` native component
- On Android: keep existing styled button with web browser flow

### 3D: Backend endpoint for native Apple token verification

**Modify:** `projulous-svc/src/auth/controllers/auth.controller.ts`

Add new endpoint for mobile native Apple auth:
```
POST /v1/auth/apple/native
Body: { identityToken: string, fullName?: { givenName, familyName }, platform: string }
```

This endpoint:
1. Verifies the Apple identity token (JWT signed by Apple) using `apple-signin-auth` or `jsonwebtoken` + Apple's public keys
2. Extracts user info (sub = Apple user ID, email)
3. Calls existing `findOrCreateSocialUser()` with provider='apple'
4. Returns tokens via code exchange flow OR directly (since this is a trusted server-to-server call)

**Install:** `npm install apple-signin-auth` in projulous-svc (for verifying Apple identity tokens)

### 3E: Enable web Apple login

**Modify:** `projulous-web/app/routes/auth/auth-layout.tsx`
- Change `SHOW_APPLE_LOGIN = false` to `true` (line 8)

The web OAuth flow (redirect to `/v1/auth/apple` -> Apple -> callback -> code exchange) is already fully implemented.

### 3F: Tests

- Backend: Test the new `/v1/auth/apple/native` endpoint with mocked Apple token verification
- Mobile: Manual test on physical iOS device (native Apple Sign-In requires real device)
- Web: Manual test of OAuth redirect flow

---

## Phase Ordering & Dependencies

```
Phase 1 (Push Sending)     -- No migration, no shared-dto changes
  1A-1C: Core push service  -- highest business value
  1D: Logout cleanup
  1E: Tests

Phase 2 (Multi-Session)    -- Requires shared-dto build + migration
  2A: Entity in shared-dto
  2F: Migration
  2B-2D: Auth service changes
  2E: Session CRON
  2G: Tests

Phase 3 (Apple Login)      -- Requires Apple Developer setup
  3A-3B: Apple credentials  -- manual setup, blocks everything else
  3C: Native iOS integration
  3D: Backend token verification endpoint
  3E: Enable web flag
  3F: Tests
```

Phases 1, 2, and 3 are largely independent and can be worked in parallel. Phase 2A/2F (entity + migration) must precede 2B-2D.

---

## Web Push: Deferred

Current 30s polling provides adequate timeliness. Web push requires service worker + FCM + VAPID keys + separate push API (not Expo), high user denial rates for permission prompts, and significant effort for marginal value. If real-time web updates become a priority, GraphQL subscriptions (already configured in app.module.ts) would be a better investment.

---

## Verification Checklist

- [ ] **Push**: Create a project on mobile -> push notification arrives on device
- [ ] **Push prefs**: Disable pushEnabled -> notification created in DB but no push sent
- [ ] **Token cleanup**: Invalid token receipt -> PushToken row deleted from DB
- [ ] **Logout cleanup**: Logout on mobile -> push token unregistered, no more pushes
- [ ] **Multi-session**: Log in on web + mobile -> refresh on web -> mobile session still valid
- [ ] **Token theft**: Replay old refresh token -> all sessions invalidated (security preserved)
- [ ] **Session CRON**: Expired sessions cleaned up daily
- [ ] **Apple iOS**: Tap Apple button -> native sheet -> authenticated
- [ ] **Apple Android**: Tap Apple button -> web browser flow -> authenticated
- [ ] **Apple web**: Tap Apple button -> redirect flow -> authenticated
- [ ] **New user Apple**: First-time Apple user -> account created, Customer role assigned
- [ ] **Existing user Apple**: User with same email -> accounts linked, appleUserId set
