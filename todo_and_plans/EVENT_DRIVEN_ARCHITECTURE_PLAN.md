# Event-Driven Architecture Plan

## Executive Summary

### Current State
The projulous-svc codebase has a solid foundation for event-driven architecture — 80+ event types, 22 event controllers with ~78 handlers, and consistent `save → emit` patterns across most services. However, the system has grown organically and accumulated significant coupling, inconsistencies, and gaps:

- **6+ services directly call NotificationService** instead of letting events drive notifications
- **4 services directly call EmailService** instead of event-driven email
- **5 circular dependencies** (forwardRef) that events could eliminate
- **30+ event types are emitted but have no handlers** (fire into void)
- **~15 multi-step methods lack transactions** where partial failure leaves inconsistent state
- **11 services emit no events at all** (auth registration, conversation lifecycle, admin actions)
- **Duplicate handling**: Some events handled by both domain controllers AND NotificationEventController
- **ProjulousEventEmitterV2 is re-instantiated per module** instead of being a shared singleton
- **All event handlers use `string` parameter type** with runtime `typeof` checks despite events always being objects
- **SQS integration is incomplete/dead code** (`receiveMessages()` never called, exchange constants are string literals not SQS URLs)

### Cross-Domain Entity Manipulation (services reaching into other domains)

| Source Service (Module) | Manipulates Entity (Domain) | Operation |
|------------------------|---------------------------|-----------|
| `auth.service.ts` (Auth) | Customer, ServiceProvider | Creates records during registration |
| `teamInvite.service.ts` (SP) | Customer, ServiceProvider | Creates records during invite accept |
| `adminUser.service.ts` (Auth) | Customer | Creates record when assigning CUSTOMER role |
| `conversation.service.ts` (AI) | CustomerProject, CustomerProjectServiceProvider | Creates project + SP link from conversation |

These are the primary candidates for event-driven decoupling — each domain should own creation of its own entities.

### Goal
Decouple side effects (notifications, email, audit logging, AI processing) from core business logic using events. Make the system easier to reason about, more resilient to partial failures, and prepared for future async processing (queues).

---

## Phase 1: Foundation Cleanup (LOW effort, HIGH value)

These changes improve the event system itself before we start moving logic into it.

### 1.1 Create SharedEventsModule (singleton ProjulousEventEmitterV2)

**Current**: Every module lists `ProjulousEventEmitterV2` as its own provider, creating duplicate instances.

**Proposed**: Create a `SharedEventsModule` that exports `ProjulousEventEmitterV2` as a singleton. All modules import `SharedEventsModule` instead of providing their own.

```
// shared/events/sharedEvents.module.ts
@Module({
  providers: [ProjulousEventEmitterV2],
  exports: [ProjulousEventEmitterV2],
})
export class SharedEventsModule {}
```

**Files to change**: Every `*.module.ts` that lists `ProjulousEventEmitterV2` as a provider (~15 modules).

**Risk**: Low. Behavioral equivalent, just consolidated.

---

### 1.2 Type-safe event handlers

**Current**: Every handler takes `data: string` and does:
```typescript
const eventData = typeof data === 'object' ? data : JSON.parse(data);
```

**Proposed**: Change all handler signatures to accept the correct type directly:
```typescript
@OnEvent(EventTypeENUM.CUSTOMER_PROJECT_CREATE)
async handler(data: EventCreateModel<CustomerProject>) { ... }
```

**Files to change**: All 22 event controller files (~78 handlers).

**Risk**: Low. SQS integration is unused/dead, so the `JSON.parse` path is never hit.

---

### 1.3 Clean up dead code and unhandled events

- Remove `receiveMessages()` from ProjulousEventEmitterV2
- Remove or comment the 30+ unhandled event types from `EventTypeENUM` (or add TODO markers)
- Remove empty showcase event controller handlers
- Clean up `EventExchangeConstants` — the first argument to `sendMessage()` is functionally unused for local emit

**Risk**: Low. Dead code removal.

---

### 1.4 Fix inconsistent notification responsibility split

**Current problem**: For `CUSTOMER_PROJECT_CREATE`:
- `CustomerProjectEventController` logs it
- `NotificationEventController` creates the notification

But for `CUSTOMER_APPLIANCE_CREATE`:
- `CustomerApplianceEventController` both logs AND notifies

**Proposed**: Pick one pattern and apply it consistently. Recommendation: domain event controllers handle logging only, notification routing is centralized (see Phase 2).

**Risk**: Low-Medium. Need to audit each event to ensure no notification is lost during migration.

---

## Phase 2: Centralized Notification Routing (MEDIUM effort, HIGH value)

This is the single highest-impact change. NotificationService is the #1 most cross-coupled service.

### 2.1 Create NotificationRouter

**Current**: 6+ services and 10+ event controllers directly call `notificationService.createNotification()`. Each caller decides: who to notify, what message, what type.

**Proposed**: Create a `NotificationRouter` service that:
1. Listens for ALL domain events via wildcard or explicit subscriptions
2. Consults a notification configuration map: `EventType → { recipientResolver, titleTemplate, messageTemplate, notificationType }`
3. Resolves recipients (excluding the actor to prevent self-notify)
4. Calls `NotificationService.createNotification()` internally

```typescript
// notification/services/notificationRouter.service.ts
const NOTIFICATION_CONFIG: Map<EventTypeENUM, NotificationConfig> = new Map([
  [EventTypeENUM.CUSTOMER_PROJECT_CREATE, {
    recipientResolver: 'actor',  // notify the user who created it (confirmation)
    titleKey: 'notification.project.created.title',
    messageKey: 'notification.project.created.message',
    notificationType: NotificationTypeENUM.CUSTOMER_PROJECT_CREATE,
  }],
  // ... one entry per notifiable event
]);
```

**Benefits**:
- Remove NotificationService import from: `spCertificationEmailParser`, `spCertificationAiReview`, `spCertificationExpiryCron`, `projectFollowUpCron`, `feedbackCron`, `FeedbackModule` (fixes improper provider import)
- Remove notification logic from all 10+ domain event controllers
- Single place to manage notification rules, prevent self-notify, respect preferences
- Delete `NotificationEventController` (its responsibility moves to NotificationRouter)

**Files to change**: ~20 files (create 1 new service, modify 6 services to remove NotificationService, modify 10+ event controllers to remove notification logic)

**Risk**: Medium. Must carefully map every existing notification to ensure no notification is dropped. Create a checklist of every `createNotification()` call site.

---

### 2.2 Fix self-notification anti-pattern

**Current**: Many events trigger notifications to `eventData.user.sub` — the user who performed the action. "You created a project" notifications are noise.

**Proposed**: NotificationRouter skips notification when `recipientUserId === actorUserId` by default, unless the notification config explicitly opts in (e.g., confirmation emails).

---

## Phase 3: Event-Driven Side Effects (MEDIUM effort, HIGH value)

Decouple email, audit logging, and AI processing from core services.

### 3.1 Event-driven email

**Current**: 4 services call `emailService.sendEmail()` directly:
- `auth.service.ts` — registration verification, forgot password
- `team.service.ts` — team invite
- `adminUser.service.ts` — admin password reset
- `spCertification.service.ts` — certification emails

**Proposed**: Each service emits a domain event (most already do). A new `EmailEventHandler` listens for relevant events and sends emails.

| Event | Email |
|-------|-------|
| USER_REGISTERED (new) | Verification email |
| SP_USER_REGISTERED (new) | SP verification email |
| PASSWORD_RESET_REQUESTED (new) | Forgot password email |
| TEAM_INVITE_CREATE | Invite email |
| SP_CERTIFICATION_* | Certification emails |

**Benefits**: Removes `EmailService` injection from 4 services. Breaks the `forwardRef` circular dependency in `auth.service.ts`.

**Risk**: Medium. Email is user-facing — must ensure no emails are lost. Add logging in the email handler for failed sends.

---

### 3.2 Event-driven audit logging

**Current**: `UserAuditLogService` is called directly by `team.service.ts` and `adminUser.service.ts`.

**Proposed**: Create an `AuditEventHandler` that listens for all events and writes audit log entries for relevant ones (admin actions, team management, etc.).

**Benefits**: Removes `UserAuditLogService` injection from services. Centralizes audit policy. Could be extended to log ALL events for a complete activity trail.

**Risk**: Low. Audit logs are append-only side effects.

---

### 3.3 Event-driven AI processing

**Current**: `spCertificationEmailParser` and `spCertification.service.ts` directly call `spCertificationAiReviewService.reviewEmailResponse()` — a slow AI operation executed synchronously.

**Proposed**: Emit `SP_CERTIFICATION_ANSWERS_SUBMITTED` or `SP_CERTIFICATION_EMAIL_RECEIVED` event. A handler in the SP module triggers the AI review asynchronously.

**Benefits**: Decouples the slow AI processing from the request lifecycle. If AI fails, the certification data is already saved.

**Risk**: Low-Medium. AI review is already error-caught. Need to ensure status transitions still work correctly.

---

### 3.4 Event-driven vote count recalculation

**Current**: `feedbackVote.service.ts` synchronously recalculates denormalized counts (2 COUNT queries + 1 UPDATE) and recomputes priority scores after every vote.

**Proposed**: Emit `FEEDBACK_VOTE_CREATE` (already exists). Handler recalculates counts and priority asynchronously.

**Benefits**: Vote API responds faster. Count recalculation is idempotent so safe to retry.

**Risk**: Low. Slight delay in count updates is acceptable for feedback votes.

---

## Phase 4: Missing Events & Auth Decoupling (MEDIUM effort, MEDIUM value)

### 4.1 Auth registration events — DECISION NEEDED

**Current**: `registerUser()`, `registerServiceProviderUser()`, and `findOrCreateSocialUser()` use `dataSource.transaction()` to atomically create User + Customer/SP + RoleMembership. No events are emitted. Additionally, `findOrCreateSocialUser()` literally duplicates the Customer + RoleMembership creation code from `registerUser()`.

**Cross-domain coupling**: AuthService directly imports `Customer` entity + repo and `ServiceProvider` entity + repo — reaching into other domains to create their records. This is the most significant example of porous domain boundaries in the codebase.

**Option A — Event-driven (eventual consistency)**:
1. Core operation: Save User record only
2. Emit `USER_REGISTERED` event with `{ userId, userType: 'CUSTOMER' | 'SERVICE_PROVIDER', name, email }`
3. CustomerModule handler creates Customer record + CUSTOMER RoleMembership
4. ServiceProviderModule handler creates SP record + SP RoleMembership
5. Eliminates code duplication between `registerUser()` and `findOrCreateSocialUser()`
6. Removes Customer/SP entity imports from AuthModule (clean domain boundary)

**Option B — Keep transaction, add events for side effects only**:
1. Keep the transaction as-is (User + Customer + RoleMembership are tightly coupled)
2. After transaction completes, emit `USER_REGISTERED` event
3. Event drives email sending (already fire-and-forget) and future side effects (welcome flow, analytics)

**Trade-off analysis**:
- Option A is architecturally cleaner — AuthService only knows about Users, each domain owns its own records
- Option A introduces a window where User exists but Customer/RoleMembership don't — `signIn()` queries `customerId` synchronously for the JWT payload, so login immediately after registration would fail
- Option A eliminates the duplicated Customer+Role creation code across 3 methods
- Option B is safer but perpetuates cross-domain coupling and code duplication
- **Hybrid approach**: Option A with a synchronous event handler (NestJS EventEmitter2 `@OnEvent` handlers run in the same tick by default) — the Customer record would exist before `registerUser()` returns, but the logic lives in CustomerModule. However, error handling becomes more complex (event handler failure won't roll back the User save).

**Recommendation**: Start with **Option B** for safety (add `USER_REGISTERED` event after transaction, drive email + future side effects). Revisit Option A or Hybrid when the event system is more mature (Phase 1-3 complete) and you can add retry/compensation logic.

---

### 4.2 Conversation lifecycle events

**Current**: `conversation.service.ts` emits NO events for: conversation creation, status changes, message additions, or project creation from conversation.

**Proposed**: Add events for key lifecycle moments:
- `CONVERSATION_CREATE`
- `CONVERSATION_STATUS_CHANGE` (important — drives the AI flow state machine)
- `CONVERSATION_PROJECT_CREATE` (when a project is created from a conversation)

**Benefits**: Enables future handlers for analytics, notifications ("your service request is being processed"), and admin dashboards.

---

### 4.3 Admin action events

**Current**: `adminUser.service.ts` emits no events for verify/unverify/delete/restore/deactivate/reactivate actions.

**Proposed**: Emit events for all admin actions. This feeds into the audit logging handler (Phase 3.2) and enables admin activity monitoring.

---

## Phase 5: Transaction Safety (MEDIUM effort, MEDIUM value)

These are multi-step methods that need either a transaction wrapper or event-driven decoupling.

### 5.1 Wrap in transactions (data must be consistent)

| Service | Method | Steps to wrap | Risk without |
|---------|--------|--------------|-------------|
| `team.service.ts` | `deactivateTeamMember()` | RoleMembership update + User.isAccountActive + tokenVersion + refreshTokenHash | User can still sign in after role deactivated |
| `team.service.ts` | `reactivateTeamMember()` | RoleMembership update + User.isAccountActive | Role active but user still flagged inactive |
| `teamInvite.service.ts` | `acceptInvite()` | User create/find + RoleMembership + Invite status update (3 sequential writes, NO transaction currently) | Orphaned user if membership save fails; invite stuck PENDING if status update fails |
| `conversation.service.ts` | `createProjectFromConversation()` | CustomerProject + CustomerProjectServiceProvider join records | Project exists but missing SP assignments |
| `conversation.service.ts` | `createConversation()` | Conversation + ConversationParticipant | Conversation with no participants |
| `spCertification.service.ts` | `initiateCertification()` | Delete old verifications + Save new ones + Update SP status + Cert log | Orphaned verifications, incorrect status |
| `spCertification.service.ts` | `requestRecertification()` | Same pattern as initiateCertification | Same risk |
| `spCertification.service.ts` | `submitSelfServiceAnswers()` | Answer updates + SP status + Cert log | Partial answers saved, wrong status |

**Note on conversation.service.ts**: `createProjectFromConversation()` is also a cross-domain concern — the AI module is reaching into Customer domain internals (CustomerProject, CustomerProjectServiceProvider repos) to create records. This logic should ideally live in CustomerModule and be triggered by a `CONVERSATION_PROJECT_REQUESTED` event.

### 5.2 Decouple via events (eventual consistency is acceptable)

| Service | Method | Decouple what | Why eventual consistency is OK |
|---------|--------|--------------|-------------------------------|
| `feedbackVote.service.ts` | `vote()` | Count recalculation + priority recomputation | Denormalized counts can be slightly stale |
| `spCertificationAiReview.service.ts` | `reviewEmailResponse()` | Notification creation after AI review | Notification delay is acceptable |
| `spCertificationExpiryCron.service.ts` | `processExpired()` | Notification per SP after status change | Notification delay is acceptable |
| `supportTicket.service.ts` | All mutations | Ticket log entries (create, addComment, updateStatus) | Log entries are append-only audit trail; slight delay is fine |
| `adminUser.service.ts` | Role assignment | Conditional Customer record creation when adding CUSTOMER role | Same pattern as auth registration — secondary record creation |

---

## Phase 6: Break Circular Dependencies (LOW effort, HIGH value)

### 6.1 forwardRef elimination targets

| Location | Circular Dependency | Resolution |
|----------|-------------------|------------|
| `auth.service.ts` | `AuthService ↔ EmailService` | Phase 3.1 removes EmailService injection entirely |
| `spCertificationAiReview.service.ts` | `↔ SpCertificationService` | Phase 3.3 decouples via events |
| `spDataEnrichment.service.ts` | `↔ PostalCodeLatLongService, GooglePlacesService, SPOfferingService` | These are legitimate data dependencies — consider extracting a shared data access layer or using events for the enrichment pipeline |
| `chat.service.ts` | `↔ ConversationService, FindServiceService, SPOfferingService` | AI chat legitimately needs these for real-time responses — events not suitable here (need synchronous response) |

**Conclusion**: 2 of 5 circular deps are directly resolved by Phases 3.1 and 3.3. The remaining 3 are in the AI pipeline where synchronous data access is necessary.

---

## Phase 7: FeedbackEventController Cleanup (LOW effort, MEDIUM value)

**Current**: FeedbackEventController contains 60+ lines of static multi-language strings, queries 3 repositories, performs AI processing, calculates milestones — it's a mini-service.

**Proposed**:
1. Extract AI processing logic to `FeedbackAIService` (may already exist — delegate call)
2. Extract vote milestone logic to a dedicated method or service
3. Move notification logic to NotificationRouter (Phase 2)
4. Move multi-language strings to i18n translation files
5. What remains: simple event logging

---

## What NOT to Change

These were evaluated and intentionally left as-is:

| Item | Reason to keep current pattern |
|------|-------------------------------|
| `auth.service.ts` registration transactions | User + Customer + RoleMembership must be atomic — JWT login needs customerId immediately (see Phase 4.1 discussion) |
| `adminRole.service.ts` bulkSetRolePermissions transaction | Atomic replace of permissions is correct |
| `feedbackCron.service.ts` trending topics transaction | Full replace of themes must be atomic |
| `chat.service.ts` → SP service dependencies | AI chat needs synchronous data access for real-time responses |
| `spDataEnrichment.service.ts` → multiple service deps | Enrichment pipeline needs direct data access |
| `billingAccount.service.ts` → Stripe flow | External API calls are inherently non-transactional; current retry-friendly pattern is correct |
| `auth.service.ts` changePassword (2-step update) | tokenVersion increment after password change is low risk; wrapping in transaction is optional |

---

## Implementation Order

```
Phase 1 (Foundation) ──→ Phase 2 (Notification Router) ──→ Phase 3 (Side Effects)
                                                         ↗
Phase 5 (Transactions) ─────────────────────────────────
                                                         ↘
Phase 4 (Missing Events) ──→ Phase 6 (Circular Deps) ──→ Phase 7 (Cleanup)
```

**Recommended sequencing**:
1. **Phase 1** first — low risk, improves the foundation everything else builds on
2. **Phase 5.1** (transactions) — independent safety fixes, can be done anytime
3. **Phase 2** — highest impact, centralizes notification routing
4. **Phase 3** — builds on Phase 2's pattern for email, audit, AI
5. **Phase 4** — adds missing events that feed into Phases 2 and 3
6. **Phase 6** — naturally resolved by Phases 3.1 and 3.3
7. **Phase 7** — cleanup once notification routing is centralized

---

## Metrics to Track

- Number of `forwardRef` usages (target: reduce from 5 to 2-3)
- Number of services directly importing NotificationService (target: 1 — NotificationRouter only)
- Number of services directly importing EmailService (target: 1 — EmailEventHandler only)
- Number of unhandled event types (target: 0)
- Number of multi-step methods without transactions (target: 0 for the identified list)
