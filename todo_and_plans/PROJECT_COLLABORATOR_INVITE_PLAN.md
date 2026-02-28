# Project Collaborator Invite Workflow — Implementation Plan

## Context

Projulous has **two invite systems**: Service Provider Team Invites (fully complete) and Project Collaborator Invites (partially built). Users can invite collaborators to their home projects via the web/mobile UI, but **the invite doesn't actually work end-to-end** — no email is sent, there's no acceptance page, new users can't register via invite, and tokens are stored insecurely. This plan completes the project collaborator invite workflow by mirroring the patterns from the working SP team invite system.

---

## Current State

| Feature | SP Team Invites | Project Collaborators |
|---------|:-:|:-:|
| Entity + DTOs | Done | Done |
| Backend CRUD service | Done | Done |
| REST + GraphQL endpoints | Done | Done |
| **Email to invitee** | Done | **Missing** |
| **Invite acceptance page (web)** | Done | **Missing** |
| **New user signup via invite** | Done | **Missing** |
| Token hashing (SHA256) | Done | **Plaintext** |
| Expiration CRON | Done | **Missing** |
| Resend/Cancel invite | Done | **Missing** |
| Mobile acceptance flow | N/A | **Missing** |
| Web UI (invite + list) | Done | Done |
| Mobile UI (invite + list) | N/A | Done |

---

## Phase 1: Security + Backend Foundation

### 1A. Entity changes (`projulous-shared-dto-node`)

**`customer/projectCollaborator.entity.ts`**
- Rename column `inviteToken` (varchar 64) → `inviteTokenHash` (varchar 64). Same type, different semantic — stores SHA256 hash instead of raw token.
- Remove `@Field()` from `inviteTokenHash` (never expose via GraphQL).
- Add `AcceptCollaboratorInviteDTO` class with: `token`, `name?`, `password?`, `verifyPassword?` (mirror `AcceptTeamInviteDTO` but simpler — no OAuth, no dual-role check).

**`shared/enums/collaboratorInviteStatus.enum.ts`**
- Add `CANCELLED = 'CANCELLED'` value.

### 1B. Migration (`projulous-svc`)

After shared-dto is built + pushed:
1. Rename column `inviteToken` → `inviteTokenHash`
2. Hash existing plaintext tokens: `UPDATE "ProjectCollaborators" SET "inviteTokenHash" = encode(digest("inviteTokenHash", 'sha256'), 'hex') WHERE "inviteTokenHash" IS NOT NULL AND "inviteStatus" = 'INVITED'`
3. Add CANCELLED to PG enum: `ALTER TYPE "public"."collaboratorinvitestatusenum" ADD VALUE IF NOT EXISTS 'CANCELLED'`

### 1C. Service updates (`projulous-svc/src/customer/services/projectCollaborator.service.ts`)

**Update existing methods:**
- `inviteCollaborator()` — Hash token with SHA256 before storing. Include `rawToken` in event payload. Add self-invite check + duplicate-invite-resend logic.
- `acceptInvite()` — Hash incoming token, look up by `inviteTokenHash`. Clear hash on acceptance.

**Add new methods:**
- `cancelInvite(user, customerProjectId, projectCollaboratorId)` — Set status CANCELLED, clear hash, emit event
- `resendInvite(user, customerProjectId, projectCollaboratorId)` — Generate new token+hash, reset expiry, emit invite event
- `declineInvite(token)` — Hash token, find record, set DECLINED (public, no auth)
- `validateCollaboratorInviteToken(token)` — Hash, look up, return `{ valid, email, projectName, role, inviterName, existingAccount, reason }` (public, no auth)
- `acceptCollaboratorInvite(dto: AcceptCollaboratorInviteDTO)` — Mirror `TeamInviteService.acceptInvite()` but for customers: hash token, find record, create new User + Customer + CUSTOMER RoleMembership if needed, link user to collaborator, return JWT tokens (auto-login). No dual-role check needed. Use transaction.

**New dependencies to inject:** User repo (read/write), Customer repo, Role repo, RoleMembership repo, AuthService, DataSource (for transactions).

### 1D. New event types (`projulous-svc/src/shared/events/eventType.enum.ts`)

Add: `PROJECT_COLLABORATOR_CANCEL`, `PROJECT_COLLABORATOR_DECLINE`

### 1E. Public auth endpoints (`projulous-svc/src/auth/controllers/auth.controller.ts`)

Add alongside existing team invite public endpoints:
- `GET /v1/auth/validate-project-invite/:token` — calls `validateCollaboratorInviteToken()`
- `POST /v1/auth/accept-project-invite` — calls `acceptCollaboratorInvite()`
- `POST /v1/auth/decline-project-invite` — calls `declineInvite()`

All rate-limited, no JWT required. The auth controller needs `ProjectCollaboratorService` injected — export it from `CustomerModule`, import into `AuthModule`.

### 1F. Authenticated controller endpoints (`projulous-svc/src/customer/controllers/projectCollaborator.controller.ts`)

Add:
- `POST :projectcollaboratorid/cancel` — requires PROJECT_COLLABORATOR_INVITE permission
- `POST :projectcollaboratorid/resend` — requires PROJECT_COLLABORATOR_INVITE permission

### 1G. CRON job (new file: `projulous-svc/src/customer/services/collaboratorInviteCron.service.ts`)

Mirror `teamInviteCron.service.ts`: daily at 4 AM UTC, mark expired INVITED collaborators as EXPIRED. Register in `customer.module.ts`.

### 1H. Event controller (`projulous-svc/src/customer/eventControllers/projectCollaborator.eventController.ts`)

Add handlers for CANCEL + DECLINE events (audit logging).

---

## Phase 2: Email Delivery

### 2A. Email handler (`projulous-svc/src/notification/services/emailEventHandler.service.ts`)

Add `@OnEvent(EventTypeENUM.PROJECT_COLLABORATOR_INVITE)` handler:
- Extract `rawToken` from event payload
- Load project name from `CustomerProject` repo (inject read repo)
- Build invite link: `${frontendUrl}/project-invite/${rawToken}`
- Send email: "You've been invited to collaborate on '{projectName}' as a {role}"
- 7-day expiry noted

### 2B. Update event emission

The updated `inviteCollaborator()` from Phase 1C already includes `rawToken` in the event payload, making it available to the email handler.

---

## Phase 3: Web Acceptance Flow

### 3A. Data access (new file: `projulous-web/app/dataAccess/customer/collaboratorInvite.da.tsx`)

Mirror `serviceProvider/invite.da.tsx`:
- `validateToken(token)` → `GET /v1/auth/validate-project-invite/{token}`
- `acceptWithPassword(token, { name, password, verifyPassword })` → `POST /v1/auth/accept-project-invite`
- `acceptExisting(token)` → `POST /v1/auth/accept-project-invite` (token only, for logged-in users)
- `decline(token)` → `POST /v1/auth/decline-project-invite`

### 3B. Acceptance page (new file: `projulous-web/app/routes/customers/projects/collaboratorInviteAccept.route.tsx`)

Mirror `inviteAccept.route.tsx` with project-specific adaptations:

**States:** `loading` | `valid-new-user` | `valid-existing-user` | `invalid` | `success`

**Flow:**
1. On mount → validate token
2. Invalid/expired → error page with reason + links to home/login
3. Valid + existing account → project info card + "Log in to accept" or "Accept" (if logged in)
4. Valid + new user → registration form: email (disabled), name, password, confirm, terms checkbox, Google OAuth option
5. On success → store JWT, redirect to `/customers/projects/{projectId}` after 3s

**Key differences from team invite page:**
- Shows project name + role instead of company name + team role
- Redirects to project detail instead of SP team dashboard
- No dual-role warning (collaborators are always customers)
- `existingAccount` flag controls which form variant shows

### 3C. Route registration (`projulous-web/app/routes.ts`)

Add public route after line 30 (existing `/invite/:token`):
```
route('/project-invite/:token', './routes/customers/projects/collaboratorInviteAccept.route.tsx'),
```

### 3D. i18n translations

Add keys to EN/ES/FR translation files under a `projectInvite` namespace for all UI strings (validating, invited, project name, roles, set up account, accept, decline, invalid, expired, success, redirecting, etc.).

---

## Phase 4: Resend/Cancel UI

### 4A. Web data access (`projulous-web/app/dataAccess/customer/projectCollaborator.da.tsx`)

Add `resendInvite()` and `cancelInvite()` methods calling the new REST endpoints from Phase 1F.

### 4B. Web CollaboratorList (`projulous-web/app/routes/customers/projects/components/CollaboratorList.component.tsx`)

For collaborators with `inviteStatus === 'INVITED'`:
- Add "Resend" button (mail/refresh icon)
- Add "Cancel" button (X icon)
- Wire to callbacks passed from parent

### 4C. Web project detail integration (`projulous-web/app/routes/customers/projects/projectDetail.route.tsx`)

Add `handleResendInvite` and `handleCancelInvite` handler functions, pass as props to `CollaboratorList`.

### 4D. Mobile data access (`projulous-mobile/dataAccess/customer/projectCollaborator.da.ts`)

Add `resendInvite()` and `cancelInvite()` methods.

### 4E. Mobile TeamTab (`projulous-mobile/components/projects/planner/TeamTab.tsx`)

For INVITED collaborators, add Resend/Cancel action buttons with confirmation alerts.

---

## Phase 5: Mobile Deep Linking (Deferred)

Universal links and deep linking require infrastructure work (apple-app-site-association file hosting, Android assetlinks.json, Expo config updates). This can be done separately. For now, mobile users tapping the email link will land on the **web acceptance page**, which works on mobile browsers. This is the same pattern used for SP team invites today.

---

## Key Architectural Decisions

1. **Accept endpoint is unauthenticated** — token itself proves authorization (same as team invites)
2. **New users get CUSTOMER role** — unlike team invites which give SERVICE_PROVIDER role
3. **SHA256 token hashing** — raw token in email, only hash stored in DB
4. **7-day expiry** — shorter than team invites' 30 days (project collaboration is more time-sensitive)
5. **Invite URL: `/project-invite/{token}`** — separate from `/invite/{token}` (team invites)
6. **Auto-login on accept** — returns JWT tokens, zero friction

## Edge Cases Handled

- User already has account + is logged in → show "Accept" button directly
- User has account but not logged in → "Log in to accept" link with redirect back
- User doesn't have account → registration form
- Invite expired → mark EXPIRED, show error
- Invite already accepted/declined/cancelled → show "already used" error
- Self-invite attempt → rejected at backend (email match check)
- Duplicate invite (same email + project) → auto-resend instead of creating duplicate

## Phase Dependencies

```
Phase 1 (Backend) ──→ Phase 2 (Email)
         │
         ├──→ Phase 3 (Web Accept)
         │
         └──→ Phase 4 (Resend/Cancel UI)

Phase 5 (Mobile Deep Links) — independent, deferred
```

Phases 2, 3, and 4 can all proceed in parallel after Phase 1 is complete.

## Critical Files

| Purpose | File |
|---------|------|
| Collaborator entity | `projulous-shared-dto-node/customer/projectCollaborator.entity.ts` |
| Collaborator status enum | `projulous-shared-dto-node/shared/enums/collaboratorInviteStatus.enum.ts` |
| Backend service (core logic) | `projulous-svc/src/customer/services/projectCollaborator.service.ts` |
| Auth controller (public endpoints) | `projulous-svc/src/auth/controllers/auth.controller.ts` |
| Collaborator controller (authed) | `projulous-svc/src/customer/controllers/projectCollaborator.controller.ts` |
| Email handler | `projulous-svc/src/notification/services/emailEventHandler.service.ts` |
| Event types | `projulous-svc/src/shared/events/eventType.enum.ts` |
| Web routes | `projulous-web/app/routes.ts` |
| **Reference**: Team invite service | `projulous-svc/src/auth/services/teamInvite.service.ts` |
| **Reference**: Team invite accept page | `projulous-web/app/routes/serviceProviders/team/inviteAccept.route.tsx` |

## Verification Plan

1. **Backend unit tests**: Token hashing, validation, acceptance (new user + existing user), cancel, resend, decline, CRON expiry
2. **Manual E2E test (web)**:
   - Invite a collaborator → verify email received with correct link
   - Click link → see acceptance page with project info
   - New user: fill form, submit → verify user created, collaborator ACCEPTED, auto-login, redirect to project
   - Existing user: log in first, navigate to link → accept → verify collaborator linked
   - Expired token → shows expired error
   - Resend → new email with fresh token, old token invalid
   - Cancel → status CANCELLED, token invalidated
3. **Mobile**: Verify resend/cancel buttons work on TeamTab
4. **Health check**: `GET http://localhost:8123/v1/healthCheck` → 200

## Migration Reminder

After Phase 1A entity changes:
1. Build & push `projulous-shared-dto-node` to git
2. `npm install projulous-shared-dto-node` in projulous-svc
3. `npm run migration:generate -- src/migrations/CollaboratorInviteTokenHash`
4. Review generated SQL — manually add the data migration (hash existing tokens) and CANCELLED enum value
5. Commit migration file
