# Service Provider Registration & Onboarding Plan

## Decision Summary

| Decision | Choice |
|----------|--------|
| SP Claim (AI-discovered) | Claim token in certification email |
| Post-registration merge | Self-service claim flow from dashboard |
| Tier selection | Post-registration onboarding (default FREE) |
| Dual roles | Deferred — single role accounts for now |
| Claim token behavior | Works for register OR login, expires 30 days |
| Claim verification | Email verification to SP record's email, admin fallback |
| TOS/Privacy | Universal (same for all roles), on User entity with version tracking |

---

## Phase 1: TOS & Privacy Policy Acceptance (All Users)

**Goal:** Every user must accept TOS and Privacy Policy at registration, with version tracking for re-acceptance when policies change.

### 1.1 New Entity: `PolicyAcceptance`

**File:** `projulous-shared-dto-node/auth/policyAcceptance.entity.ts`

```
Table: policy_acceptances
- policyAcceptanceId: UUID (PK)
- userId: UUID (FK → users)
- policyType: PolicyTypeENUM (TERMS_OF_SERVICE | PRIVACY_POLICY)
- policyVersion: string (e.g., "1.0", "2.0")
- acceptedAt: timestamp
- ipAddress: string (nullable — for audit trail)
- userAgent: string (nullable — for audit trail)
- standardFields: StandardFields
```

### 1.2 New Enum: `PolicyTypeENUM`

**File:** `projulous-shared-dto-node/shared/enums/policyType.enum.ts`

```typescript
export enum PolicyTypeENUM {
  TERMS_OF_SERVICE = 'TERMS_OF_SERVICE',
  PRIVACY_POLICY = 'PRIVACY_POLICY',
}
```

### 1.3 Policy Version Config

**File:** `projulous-svc/src/shared/configs/policyVersions.ts`

```typescript
export const CURRENT_POLICY_VERSIONS = {
  [PolicyTypeENUM.TERMS_OF_SERVICE]: '1.0',
  [PolicyTypeENUM.PRIVACY_POLICY]: '1.0',
};
```

When policies change, bump the version here. The system will detect users who haven't accepted the new version.

### 1.4 Registration Changes

**Both `registerUser` and `registerServiceProviderUser`:**
- Add `acceptTos: boolean` and `acceptPrivacyPolicy: boolean` to registration DTOs
- Validate both are `true` or reject registration with 400 error
- On success, create 2 `PolicyAcceptance` records (TOS + Privacy) with current versions
- Capture IP and User-Agent from request headers

**OAuth registration (`findOrCreateSocialUser`):**
- OAuth callback cannot capture TOS acceptance (no form)
- After OAuth creates a new user, redirect to a "complete registration" page that requires TOS/Privacy acceptance before they can proceed
- Store a flag on the JWT or in a transient state to enforce this check

### 1.5 Re-acceptance Flow

- On login, check if user's latest `PolicyAcceptance` records match `CURRENT_POLICY_VERSIONS`
- If outdated, return a flag in the auth response (e.g., `requiresPolicyAcceptance: true` with `outdatedPolicies: ['TERMS_OF_SERVICE']`)
- Frontend/mobile shows a blocking modal requiring acceptance before continuing
- New `POST /v1/auth/accept-policies` endpoint to record new acceptance

### 1.6 GraphQL Query

- `myPolicyAcceptances` — returns user's acceptance history
- Used by frontend to check if re-acceptance is needed on app load

---

## Phase 2: Claim Token System (AI-Discovered SP Association)

**Goal:** When we send a certification email to an AI-discovered SP, include a claim token that lets them register or log in and associate their account with that SP record.

### 2.1 New Entity: `ServiceProviderClaimToken`

**File:** `projulous-shared-dto-node/serviceProvider/spClaimToken.entity.ts`

```
Table: service_provider_claim_tokens
- claimTokenId: UUID (PK)
- serviceProviderId: UUID (FK → service_providers)
- token: string (unique, cryptographically random — use crypto.randomUUID() or similar)
- expiresAt: timestamp (createdAt + 30 days)
- claimedAt: timestamp (nullable — set when used)
- claimedByUserId: UUID (FK → users, nullable — who used it)
- standardFields: StandardFields
```

### 2.2 Certification Email Enhancement

**In `spCertification.service.ts` → `recordEmailSent()`:**
- Generate a `ServiceProviderClaimToken` when sending certification email
- Include a claim link in the email body: `{FRONTEND_URL}/sp/claim?token={token}`
- Email template should explain: "If you'd like to manage your business profile on Projulous, click here to create your account or sign in."

### 2.3 Claim Endpoint

**New REST endpoint:** `POST /v1/auth/claim-service-provider`

```typescript
Input: {
  token: string;         // claim token from email
}
Headers: Authorization (optional — if logged in)
```

**Logic:**
1. Validate token exists, not expired, not already claimed
2. **If user is authenticated** (has valid JWT):
   - Associate the SP record with their existing user account
   - Create `RoleMembership` (User → SP, teamRole: ADMIN)
   - Mark token as claimed
3. **If user is NOT authenticated:**
   - Return the SP details (name, email) + a `claimContext` token
   - Frontend redirects to registration page with `claimContext` in state
   - After registration completes, automatically associate SP record

### 2.4 Registration with Claim Context

**Modify `registerServiceProviderUser`:**
- Accept optional `claimToken: string` parameter
- If provided, skip creating a new SP record — instead associate with the existing one
- Update the SP's `discoverySource` to remain `AI_DISCOVERED` (don't overwrite)
- Mark the claim token as claimed

**Modify OAuth SP flow:**
- If `claimToken` is in the OAuth state parameter, carry it through the flow
- After OAuth user creation, associate with the claimed SP record

### 2.5 Admin: Resend Claim Email

- Admin can regenerate a claim token and resend the certification email
- Old tokens for that SP are invalidated when a new one is generated

---

## Phase 3: Self-Service SP Claim Flow (Post-Registration Merge)

**Goal:** An SP user who registered without associating can search for and claim their AI-discovered business record from their dashboard.

### 3.1 Search Endpoint

**New GraphQL query:** `searchUnclaimedServiceProviders`

```typescript
Input: {
  searchTerm: string;    // business name search
  postalCode?: string;   // optional location filter
}
Output: [{
  serviceProviderId: string;
  name: string;
  maskedEmail: string;   // "j***@example.com" — partial for privacy
  postalCode: string;
  discoverySource: DiscoverySourceENUM;
  // Only show AI_DISCOVERED SPs that have NO associated users
}]
```

**Access:** Requires authenticated SP user (SERVICE_PROVIDER role)

### 3.2 Initiate Claim

**New REST endpoint:** `POST /v1/service-provider/claim/initiate`

```typescript
Input: {
  serviceProviderId: string;
}
```

**Logic:**
1. Verify the SP record exists and has no associated users (no RoleMembership)
2. Verify the SP was `AI_DISCOVERED` (not already self-registered)
3. Generate a verification code and send it to the SP record's email on file
4. Create a `ServiceProviderClaim` record (see 3.3) with status PENDING
5. Return `{ claimId, maskedEmail }` so the user knows where the code went

### 3.3 New Entity: `ServiceProviderClaim`

**File:** `projulous-shared-dto-node/serviceProvider/spClaim.entity.ts`

```
Table: service_provider_claims
- claimId: UUID (PK)
- serviceProviderId: UUID (FK → service_providers)
- claimantUserId: UUID (FK → users — who is trying to claim)
- status: ClaimStatusENUM (PENDING_VERIFICATION | VERIFIED | ADMIN_REVIEW | APPROVED | REJECTED)
- verificationCode: string (6-digit code sent to SP's email)
- verificationCodeExpiry: timestamp (30 min)
- verificationAttempts: int (default: 0, max: 5)
- adminNotes: text (nullable)
- resolvedByUserId: UUID (FK → users, nullable — admin who resolved)
- resolvedAt: timestamp (nullable)
- standardFields: StandardFields
```

### 3.4 Verify Claim (Email Code)

**New REST endpoint:** `POST /v1/service-provider/claim/verify`

```typescript
Input: {
  claimId: string;
  verificationCode: string;
}
```

**Logic:**
1. Validate claim exists, belongs to authenticated user, status is PENDING_VERIFICATION
2. Check code matches and hasn't expired
3. Increment `verificationAttempts` — if >= 5, reject claim
4. On match:
   - Update claim status to VERIFIED → APPROVED (auto-approve on email match)
   - Create `RoleMembership` (User → SP, teamRole: ADMIN)
   - Log in `CertificationLog` as `SP_SELF_SERVICE_SUBMITTED`

### 3.5 Admin Fallback

**If the user can't verify via email** (e.g., they don't have access to the email on the SP record):

**New REST endpoint:** `POST /v1/service-provider/claim/request-admin-review`

```typescript
Input: {
  claimId: string;
  evidence: string;      // free-text explanation of why they own this business
}
```

**Logic:**
1. Update claim status to `ADMIN_REVIEW`
2. Emit event → notification to admin team
3. Admin reviews via admin dashboard and approves/rejects

**Admin endpoints:**
- `POST /v1/admin/service-provider/claims` — list pending claims
- `POST /v1/admin/service-provider/claims/:claimId/resolve` — approve or reject

---

## Phase 4: SP Onboarding & Tier Selection (Post-Registration)

**Goal:** After registration and email verification, guide SPs through an onboarding flow that includes tier selection.

### 4.1 Onboarding State Tracking

**New fields on ServiceProvider entity:**

```
- onboardingCompleted: boolean (default: false)
- onboardingCompletedAt: timestamp (nullable)
```

### 4.2 Onboarding Steps

The onboarding flow runs on first login (or whenever `onboardingCompleted === false`).

**Steps:**
1. **Business Profile** — Confirm/edit: company name, description, phone, email, website, postal code
2. **Service Offerings** — Select service categories they provide (uses existing `ServiceProviderOffering` entity)
3. **Tier Selection** — Show plan comparison (FREE/STARTER/PRO/PINNACLE) with features/pricing. FREE is pre-selected. Selecting a paid tier triggers billing setup.
4. **Complete** — Mark `onboardingCompleted = true`

### 4.3 Tier Selection Endpoint

**New REST endpoint:** `POST /v1/service-provider/select-tier`

```typescript
Input: {
  membershipTier: MembershipTierENUM;
}
```

**Logic:**
- If FREE → update `membershipTier` directly
- If paid tier → initiate billing flow (Stripe or similar — deferred to billing integration phase)
- For now, all tiers can be selected freely (billing enforcement comes later)

### 4.4 Onboarding Completion

**New REST endpoint:** `POST /v1/service-provider/complete-onboarding`

**Logic:**
- Validate minimum required fields are filled (name, at least 1 offering)
- Set `onboardingCompleted = true`, `onboardingCompletedAt = now()`
- Emit `SP_ONBOARDING_COMPLETED` event

### 4.5 Frontend Enforcement

- On SP login, check `onboardingCompleted`
- If false, redirect to `/sp/onboarding` — block access to dashboard until complete
- Onboarding is a multi-step wizard component

---

## Phase 5: OAuth Registration Improvements

**Goal:** Ensure OAuth (Google/Apple/Facebook) SP registration properly handles TOS acceptance and claim tokens.

### 5.1 OAuth SP Flow Updates

**Current flow:**
1. User clicks "Sign up as SP with Google"
2. OAuth callback creates user + empty SP record
3. User lands on dashboard

**Updated flow:**
1. User clicks "Sign up as SP with Google"
2. If claim token present, include in OAuth state: `state=sp|claim:{token}`
3. OAuth callback creates user (or links to existing)
4. Redirect to "Complete Registration" page:
   - TOS/Privacy acceptance checkboxes (mandatory)
   - If claim token: associate with existing SP record
   - If no claim token: create new SP record
5. On submit → create PolicyAcceptance records, finalize SP association
6. Redirect to onboarding flow

### 5.2 State Parameter Enhancement

**Current OAuth state values:** `mobile`, `sp`, `web` (default)

**New format:** `{platform}|{intent}|{claimToken?}`
- Examples: `web|sp`, `mobile|sp|claim:abc123`, `web|customer`

---

## Implementation Order

### Tier A — Foundation (Do First)
1. **Phase 1**: TOS/Privacy entity + acceptance at registration + re-acceptance flow
2. **Phase 2.1-2.2**: Claim token entity + certification email enhancement

### Tier B — Core SP Registration
3. **Phase 2.3-2.4**: Claim endpoint + registration with claim context
4. **Phase 4.1-4.2**: Onboarding state + SP onboarding flow (frontend)
5. **Phase 4.3-4.5**: Tier selection during onboarding

### Tier C — Self-Service Claim
6. **Phase 3**: Full self-service claim flow (search, verify, admin fallback)

### Tier D — OAuth Polish
7. **Phase 5**: OAuth flow improvements for TOS + claim tokens

---

## Entities to Create/Modify

### New Entities (projulous-shared-dto-node)
- `PolicyAcceptance` — TOS/Privacy acceptance records
- `ServiceProviderClaimToken` — Claim tokens for AI-discovered SPs
- `ServiceProviderClaim` — Self-service claim requests

### New Enums
- `PolicyTypeENUM` — TERMS_OF_SERVICE, PRIVACY_POLICY
- `ClaimStatusENUM` — PENDING_VERIFICATION, VERIFIED, ADMIN_REVIEW, APPROVED, REJECTED

### Modified Entities
- `ServiceProvider` — add `onboardingCompleted`, `onboardingCompletedAt`
- `RegisterServiceProviderDTO` — add `acceptTos`, `acceptPrivacyPolicy`, `claimToken`
- `RegisterUserDTO` (if exists) — add `acceptTos`, `acceptPrivacyPolicy`

### New Permissions
- `SP_CLAIM_INITIATE` — initiate a claim on an unclaimed SP
- `SP_CLAIM_VERIFY` — verify a claim with email code
- `SP_CLAIM_ADMIN_REVIEW` — admin: view/resolve claims
- `SP_ONBOARDING_UPDATE` — update onboarding progress
- `POLICY_ACCEPTANCE_READ` — read own policy acceptances
- `POLICY_ACCEPTANCE_CREATE` — accept policies

---

## Migration Reminder

After entity changes, the user must:
1. Build & push `projulous-shared-dto-node` to git
2. `npm install projulous-shared-dto-node` in projulous-svc
3. `npm run migration:generate -- src/migrations/SpRegistrationAndTos`
4. Review generated SQL
5. Commit migration file
