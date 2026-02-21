# Logging & Auditing — Implementation Plan & Status

> **Status**: COMPLETED
> **Completed**: 2026-02-19
> **Scope**: shared-dto, projulous-svc, projulous-web

---

## Overview

Comprehensive logging and auditing system that captures every data-changing user interaction (create/update/delete) into a queryable audit trail, and logs every AI interaction for training/evaluation/cost tracking. Includes admin UI for both.

---

## Phase 1: AuditLog Entity & Infrastructure — COMPLETED

### Shared DTO (projulous-shared-dto-node)

| File | Description |
|------|-------------|
| `shared/enums/auditAction.enum.ts` | Pure enum: CREATE, UPDATE, DELETE, RESTORE, STATUS_CHANGE (browser-safe, no registerEnumType) |
| `audit/auditLog.entity.ts` | Unified audit table with entityName discriminator, append-only (CreateDateColumn only) |
| `audit/index.ts` | Barrel export |
| `shared/enums/index.ts` | Updated to export AuditActionENUM |
| `index.ts` | Updated to export Audit module |

### Backend (projulous-svc)

| File | Description |
|------|-------------|
| `src/audit/auditEventMap.ts` | Maps all 223 EventTypeENUM values to `{entityName, action}` or null (skip) |
| `src/audit/audit.service.ts` | Fire-and-forget writes + paginated read queries with filters |
| `src/audit/auditEventHandler.service.ts` | Unified `EventEmitter2.onAny()` listener, creates audit entries for mapped events |
| `src/audit/audit.resolver.ts` | GraphQL read-only resolver, SUPER_ADMIN_SUPER_ADMIN only |
| `src/audit/audit.module.ts` | NestJS module importing LoggingModule, SharedEventsModule, TypeORM for AuditLog + User |
| `src/app.module.ts` | Added AuditLog entity + AuditModule import |
| `src/data-source.ts` | Added AuditLog entity for migration CLI |

### AuditLog Schema

```
auditLogId        uuid PK
entityName        varchar(100)     -- e.g. "CustomerProject"
entityId          uuid             -- PK of affected record
action            AuditActionENUM  -- CREATE/UPDATE/DELETE/RESTORE/STATUS_CHANGE
eventType         varchar(100)     -- raw EventTypeENUM value
userId            uuid FK -> Users -- who performed the action
customerId        uuid nullable
serviceProviderId uuid nullable
changedFields     jsonb nullable   -- [{field, newValue}] for updates
newValues         jsonb nullable   -- full record snapshot for creates
metadata          jsonb nullable   -- IP, source, etc (future)
correlationId     uuid nullable    -- groups related ops (future)
createdDate       timestamp        -- append-only, no updatedDate
```

---

## Phase 2: Event Payload Fixes — COMPLETED

Added `user` (and where applicable `customerId`/`serviceProviderId`) to ALL event emission payloads across **33+ service files**.

### Services Updated

**Auth context (2 files):**
- `adminUser.service.ts` — 5 calls, synthetic `{ sub: adminUserId }`
- `auth.service.ts` — 6 calls, synthetic user for pre-login contexts

**Customer context (already done in prior session, ~15 files):**
- customerProject, customerAppliance, customerPlace, applianceServiceRecord, projectServiceNeed, appliancePhoto, applianceDevice, savedServiceProvider, maintenanceReminder, maintenanceTemplate, projectPhase, projectCollaborator, projectNote, customer

**SP context (~7 files):**
- serviceProvider, serviceProviderOffering, offering, spCertification, team, scheduleEntry, showcaseProject

**Other contexts (11 files):**
- notification, vendorPageConfig, vendorPageFaq, vendorPageServiceType, vendorPageShowcaseProject, feedbackSubmission, feedbackVote, feedbackComment, helpArticle, helpCategory, helpFaq, supportTicket, billingAccount, quoteRequest, conversation

**Skipped (2 files):**
- `spCertificationExpiryCron.service.ts` — CRON job, no user context
- `spCertificationEmailParser.service.ts` — webhook handler, no user context

**Already correct (7 files):**
- maintenanceReminder, maintenanceTemplate, serviceProvider, serviceProviderOffering, billingAccount, quoteRequest, teamInvite

---

## Phase 3: AI Interaction Logging — COMPLETED

### Shared DTO

| File | Description |
|------|-------------|
| `projulousAI/aiInteractionLog.entity.ts` | AI telemetry entity with all LLM call metadata |
| `projulousAI/index.ts` | Barrel export |

### Backend

| File | Description |
|------|-------------|
| `src/projulousAI/constants/aiInteractionConstants.ts` | AIProviderENUM (GEMINI, OPENAI), AIOperationENUM (~15 operations) |
| `src/projulousAI/services/aiInteractionLogger.service.ts` | Fire-and-forget + sync logging, paginated queries |
| `src/projulousAI/utils/withAILogging.ts` | `withGeminiLogging` / `withOpenAILogging` wrapper utilities |
| `src/projulousAI/resolvers/aiInteractionLog.resolver.ts` | GraphQL read-only resolver, SUPER_ADMIN_SUPER_ADMIN only |
| `src/projulousAI/projulousAI.module.ts` | Added AIInteractionLog entity + AIInteractionLoggerService + resolver |

### AIInteractionLog Schema

```
aiInteractionLogId    uuid PK
provider              varchar(64)     -- 'GEMINI' | 'OPENAI'
model                 varchar(128)    -- e.g. 'gemini-3-flash-preview'
operation             varchar(128)    -- e.g. 'CLASSIFY_OFFERING_TYPE'
callerService         varchar(128)    -- e.g. 'ChatService'
callerMethod          varchar(128)    -- e.g. 'handleProvidersFoundMessage'
systemPrompt          text nullable
userInput             text nullable
rawResponse           text nullable
parsedResponse        text nullable
validatedResponse     text nullable
wasValidationFallback boolean
promptTokens          int nullable
completionTokens      int nullable
totalTokens           int nullable
latencyMs             int
temperature           float nullable
responseMimeType      varchar(64) nullable
usedJsonSchema        boolean
usedGoogleSearch      boolean
success               boolean
errorMessage          text nullable
retryAttempt          int default 0
conversationId        uuid nullable FK
conversationMessageId uuid nullable
userId                uuid nullable FK
parentInteractionId   uuid nullable
stepIndex             smallint default 0
createdDate           timestamp
```

### LLM Call Sites Instrumented (15 total)

| Service | Method | Provider | Operation |
|---------|--------|----------|-----------|
| FindServiceService | extractPostalCodeFromQuery | Gemini | EXTRACT_POSTAL_CODE |
| FindServiceService | getOfferingTypeGPT | Gemini | CLASSIFY_OFFERING_TYPE |
| FindServiceService | getBestServiceProviderIdsGPT | OpenAI | RANK_SERVICE_PROVIDERS |
| FindServiceService | addServiceProvidersForCityorPostalCodeGPT | Gemini | DISCOVER_SERVICE_PROVIDERS |
| ChatService | handleProvidersFoundMessage (intent) | Gemini | CLASSIFY_PROVIDER_INTENT |
| ChatService | handleProvidersFoundMessage (Q&A) | Gemini | PROVIDER_QA |
| ProjectPlannerService | detectComplexProjectIntent | Gemini | DETECT_COMPLEX_PROJECT |
| ProjectPlannerService | handlePlanningIntake | Gemini | PLANNING_INTAKE |
| ProjectPlannerService | generateProjectPlan | Gemini | GENERATE_PROJECT_PLAN |
| ProjectPlannerService | generateProjectPlanForProject | Gemini | GENERATE_PROJECT_PLAN_FOR_PROJECT |
| ProjectPlannerService | handlePhaseQA | Gemini | PHASE_QA |
| ProjectPlannerService | handlePlanModification | Gemini | PLAN_MODIFICATION |
| ProjectPlannerService | handleQuoteComparison | Gemini | QUOTE_COMPARISON |
| AppliancePhotoAIService | extractFromPhoto | Gemini | EXTRACT_APPLIANCE_FROM_PHOTO |
| AppliancePhotoAIService | extractWithFallback | Gemini | EXTRACT_APPLIANCE_FALLBACK |

---

## Phase 4: Admin Web UI — COMPLETED

### Frontend (projulous-web)

| File | Description |
|------|-------------|
| `app/dataAccess/admin/auditLog.da.tsx` | GraphQL data access for audit logs with filter support |
| `app/dataAccess/admin/aiInteractionLog.da.tsx` | GraphQL data access for AI interaction logs |
| `app/routes/admin/audit/auditLogAdmin.route.tsx` | Audit log admin page with filters, table, expandable rows, pagination |
| `app/routes/admin/aiLogs/aiLogsAdmin.route.tsx` | AI log admin page with filters, table, expandable rows, pagination |
| `app/routes.ts` | Added routes: `/admin/audit-logs`, `/admin/ai-logs` |
| `app/nav/sidebar.tsx` | Added nav links (ClipboardList, BrainCircuit icons), gated by SUPER_ADMIN |

### UI Features

**Audit Logs Page (`/admin/audit-logs`):**
- Filters: Entity Name, Entity ID, User ID, Action dropdown, Date From/To
- Color-coded action badges (CREATE=green, UPDATE=blue, DELETE=red, RESTORE=purple, STATUS_CHANGE=amber)
- Expandable rows showing changedFields, newValues, metadata as formatted JSON
- Pagination with page count

**AI Logs Page (`/admin/ai-logs`):**
- Filters: Operation, Model, Provider, Success/Failed, Conversation ID, Date From/To
- Provider badges (GEMINI=blue, OPENAI=purple), success badges
- Expandable rows showing full system prompt, user input, raw response, caller info
- Token counts, latency display, retry badges

---

## Security

- Both resolvers: `@UseGuards(GraphQLAccessTokenGuard, PermissionsGQLGuard)` + `@Permissions(SUPER_ADMIN_SUPER_ADMIN)`
- Both tables are **append-only** — no update/delete mutations exposed via API
- Audit writes are fire-and-forget (never block main operations)
- Text fields truncated at 10,000 chars to prevent storage abuse

---

## Database

- Tables `AuditLogs` and `AIInteractionLogs` created in prod via `synchronize: true`
- No migration file needed (tables already exist)
- `data-source.ts` updated with both entities for future migration tracking

---

## Key Design Decisions

1. **Single unified AuditLog table** with entityName discriminator — cross-domain queries
2. **Event-driven approach** via `EventEmitter2.onAny()` — leverages existing event infrastructure
3. **No old-value capture** — prior values recoverable from preceding audit entry
4. **Separate AIInteractionLog** — keeps AI telemetry separate from user-facing ConversationMessage
5. **Fire-and-forget writes** — audit/AI logging never blocks or fails the main operation
6. **Append-only entities** — no StandardFields, only CreateDateColumn
