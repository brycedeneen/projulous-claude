# Projulous — Consolidated Plan & TODO

> **Last Updated**: 2026-02-21 (Multi-session auth, SP registration, event-driven refactor completed)

---

## Pre-Launch Bugs & QA Fixes

Open issues from QA reports (manual-test-report.md, QA_REPORT_2026-02-18.md).

### High Priority

| # | Issue | Source | Project | Effort |
|---|-------|--------|---------|--------|
| 1 | ~~**Admin guard too permissive**~~ — FIXED: per-route permission map in AdminGuardLayout, SUPER_ADMIN bypasses | QA-MAJ-1/2 | web | done |
| 2 | ~~**AuthMethodIcons shows "Password" for OAuth-only users**~~ — FIXED: backend now returns `hasPassword` boolean, detail page uses it | QA-MAJ-3 | web + svc | done |
| 3 | ~~**Browse All Services shows only 1 vendor type**~~ — complete | MT-MAJ-1 | DB ops / web | done |
| 4 | ~~**Vendor page shows 11% Satisfaction Rate**~~ — test data only, ignored | MT-MAJ-2 | svc | n/a |

### Medium Priority

| # | Issue | Source | Project | Effort |
|---|-------|--------|---------|--------|
| 5 | ~~**Seed help center content**~~ — complete | QA-MED-1 | DB ops | done |
| 6 | ~~**Seed project showcase**~~ — complete | QA-MED-2 | DB ops | done |
| 7 | ~~**Missing BILLING i18n key**~~ — FIXED: translations exist in all 3 languages | MT-MIN-2 | web | done |

### Low Priority

| # | Issue | Source | Project | Effort |
|---|-------|--------|---------|--------|
| 8 | ~~**Sidebar shows customer items to anonymous users**~~ — FIXED: `handleProtectedNavigation` redirects to login | MT-MIN-1 | web | done |
| 9 | ~~**SP Certification 403 error**~~ — FIXED: added 403 checks to handleSubmit and handleRecertification | MT-MIN-3 | web | done |
| 10 | ~~**Ideas page redirect for anonymous**~~ — FIXED: shows sign-in prompt with explanation | MT-MIN-4 | web | done |
| 11 | ~~**Contact page "Start Chat" non-functional**~~ — FIXED: removed live chat card, ticket + email remain | QA-LOW-1 | web | done |
| 12 | ~~**Community Resources links go to "#"**~~ — FIXED: removed section (no real destinations yet) | QA-LOW-2 | web | done |
| 13 | ~~**Plumbing vendor page test FAQ data**~~ — test data only, ignored | QA-LOW-3 | DB ops | n/a |
| 14 | ~~**FAQ modal hardcodes dark theme**~~ — FIXED: FAQ + Showcase modals now have proper light/dark variants | QA-MIN-3 | web | done |
| 15 | ~~**Hover tooltips**~~ — FIXED: ~55 title attrs across 25 files + shared Button component + i18n keys (EN/ES/FR) | hover-tooltips-plan.md | web | done |

### ~~Pending Migrations (AI Guardrails)~~ — COMPLETE

Migration `1771547752361-AddAiGuardrailsSchemaChanges.ts` handles all changes: `AI_RECOMMENDED` enum values, `DiscoverySourceENUM` type, `discoverySource` column.

### ~~Personas Not Yet Fully Tested~~ — COMPLETE

Both Customer (9 areas) and Service Provider (9 areas) fully tested per `manual-test-report.md` (2026-02-19). Only minor issues found (MIN-2, MIN-3), both now fixed.

---

## Pre-Scaling (only matters for multi-instance deploys)

| # | Item | Project | Effort |
|---|------|---------|--------|
| 1 | **Permissions caching** — cache in JWT or short-lived Redis | svc | 4h |
| 2 | **OAuth code store -> Redis/DB** — currently in-memory Map (60s TTL) | svc | 3h |
| 3 | **Discovery cache -> Redis** — currently in-memory Map (5-min cooldown) | svc | 3h |
| 4 | **DB log retention CRON** — batched deletes for AuditLogs (12mo) + AIInteractionLogs (6mo) | svc | 3h |
| 5 | **Explicit connection pool sizes** — add max to write/read DataSources | svc | 15m |
| 6 | **Autovacuum tuning** — aggressive vacuum for log tables after retention introduces DELETEs | migration | 30m |

Items 4-6 from `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` Tier 1.

---

## Active Future Plans

### Push Notifications, Multi-Session Auth & Apple Login
**File**: `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md`
**Status**: Phase 2 COMPLETE, Phases 1 & 3 NOT STARTED

| Phase | Description | Effort | Status |
|-------|-------------|--------|--------|
| 1 | Backend push notification sending via expo-server-sdk (PushNotificationService) | 4-6h | not started |
| 2 | ~~Multi-session refresh tokens (RefreshTokenSession entity, per-device hashes)~~ | 6-8h | **DONE** |
| 3 | Complete Apple Sign-In (credentials, native iOS, web feature flag) | 4-6h | not started |

### ~~SP Registration & Onboarding~~ — COMPLETE
**File**: `SP_REGISTRATION_PLAN.md`
**Status**: ALL 5 PHASES COMPLETE (2026-02-21)

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | ~~TOS/Privacy acceptance (PolicyAcceptance entity, re-acceptance flow)~~ | **DONE** (prev) |
| 2 | ~~Claim token system (AI-discovered SP association via email link)~~ | **DONE** (prev) |
| 3 | ~~Self-service SP claim (search unclaimed SPs, email verification, admin fallback)~~ | **DONE** |
| 4 | ~~SP onboarding wizard (profile, offerings, complete flow)~~ | **DONE** |
| 5 | ~~OAuth registration improvements (TOS + claim token in OAuth flow)~~ | **DONE** |

### ~~Event-Driven Architecture Refactor~~ — COMPLETE
**File**: `EVENT_DRIVEN_ARCHITECTURE_PLAN.md`
**Status**: ALL 7 PHASES COMPLETE (2026-02-21)

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | ~~Foundation: SharedEventsModule singleton, dead code cleanup, EventExchangeConstants removal~~ | **DONE** |
| 2 | ~~Notification routing via events (NotificationRouterService)~~ | **DONE** |
| 3 | ~~Event-driven email, audit (decoupled EmailService & UserAuditLogService from business services)~~ | **DONE** |
| 4 | ~~Missing events (auth, conversation, admin) — verified all present~~ | **DONE** |
| 5 | ~~Transaction safety — verified all multi-step mutations wrapped~~ | **DONE** |
| 6 | ~~Circular dependency documentation (forwardRef comments on 3 modules)~~ | **DONE** |
| 7 | ~~FeedbackEventController cleanup — verified already clean~~ | **DONE** |

### Project Planner — Remaining Work
**File**: `PROJECT_PLANNER_PLAN.md`
**Status**: Sprints 1-6 COMPLETE. Sprint 7 + Phase 6 NOT STARTED.

| Item | Description |
|------|-------------|
| Sprint 7 | Notifications & Polish (plan ready notifications, phase completion, etc.) |
| Phase 6 | Collaborator Auth & Access (invite collaborators, shared project editing) |

### ~~Audit Log AI Analysis~~ — COMPLETE
**File**: `AUDIT_AI_ANALYSIS_PLAN.md`
**Status**: COMPLETE

~~"PJ Analyze" mode for audit logs admin page — select rows, send to Gemini for summarization, pattern detection, and troubleshooting suggestions.~~

### MCP Adapter (Hybrid Tool Layer Phase 5)
**File**: `HYBRID_TOOL_LAYER_PHASE5_MCP_ADAPTER.md`
**Status**: DEFERRED (post-launch)

Expose shared tool registry via MCP, migrate existing MCP project tools, add permission checks.

---

## Future Features (needs product decisions)

| Feature | Effort | Status | Files |
|---------|--------|--------|-------|
| **Stripe Billing** | 8-12 weeks | Plans written | (plans removed — were in old master plan references) |
| **Scheduling** | ~16 weeks | Plans written | `scheduling/` directory (3 files) |
| **Project Showcase (full)** | 2-3 weeks | Not started | Needs S3 infrastructure |
| **SP Quote Request/Response** | 2-3 weeks | Not started | Real quote flow: customer sends request, SP responds with estimate/availability |

---

## Deferred / Low Priority

| Item | Notes |
|------|-------|
| Boilerplate try/catch decorator | Cosmetic, 200+ methods, high risk-to-reward |
| ~~~20+ `any` types in codebase~~ | DONE: 381 catch blocks fixed in web (116 files), 5 in svc (3 files), shared `getErrorMessage()` utilities |
| ~~localStorage permissions UI exposure~~ | DONE: Tiered log access — `LOGS_READ` gets redacted fields, `LOGS_SUPER_ADMIN_READ`/`SUPER_ADMIN` sees all. Added `AuthUtil.hasAnyPermission()` helper |
| AI Guardrails Tier 5 (prompt eval framework, image moderation, feedback cost optimization) | See `AI_GUARDRAILS_PLAN.md` |
| AI Guardrails deferred items (auth gate for discovery, token/cost tracking, off-topic pre-filter, periodic cleanup CRON) | See `AI_GUARDRAILS_PLAN.md` |
| DB log separation (Tier 2-3) | Partition at 500K+ rows, separate DB at 10M+ rows. See `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` |
| MCP OAuth multi-provider (Apple + Facebook) | See `MCP_OAUTH_PLAN.md` Phase 2 |

---

## Recently Completed

| Feature | Date | Plan File |
|---------|------|-----------|
| **SP Ranking System** — Point-based weighted random ranking (tier + rating + projects), Efraimidis-Spirakis for certified SPs, projectsAddedCount counter via events | 2026-02-22 | n/a |
| **Audit Log AI Analysis** — "PJ Analyze" mode: select audit rows, Gemini summarization/pattern detection, admin UI integration | 2026-02-21 | `AUDIT_AI_ANALYSIS_PLAN.md` |
| **Event-Driven Architecture** — All 7 phases: SharedEventsModule, NotificationRouter, email/audit decoupling, forwardRef docs, EventExchangeConstants removal (45 files) | 2026-02-21 | `EVENT_DRIVEN_ARCHITECTURE_PLAN.md` |
| **SP Registration & Onboarding** — Phases 3-5: self-service claim (web pages + admin), onboarding wizard (backend + frontend), OAuth claim token passthrough | 2026-02-21 | `SP_REGISTRATION_PLAN.md` |
| **Multi-Session Refresh Tokens** — RefreshTokenSession entity, per-device token hashing, platform tracking | 2026-02-21 | `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` |
| **Type Safety & Log Access** — Fixed all `catch: any` (386 blocks, 119 files), tiered LOGS_READ/SUPER_ADMIN field filtering | 2026-02-21 | n/a |
| **Logging & Auditing** — AuditLog (223 event types), AIInteractionLog (15 LLM sites), admin UI | 2026-02-19 | `LOGGING_AUDITING_PLAN.md` |
| **AI Guardrails Tiers 1-4** — sanitization, rate limiting, output validation, ownership checks, auto-cert removal, discovery flag | 2026-02-19 | `AI_GUARDRAILS_PLAN.md` |
| **MCP OAuth Phase 1a+1b** — Google OAuth via McpAuthModule, API keys with argon2 hashing, web UI | 2026-02-18 | `MCP_OAUTH_PLAN.md` |
| **Maintenance Reminders V1** — 3 entities, CRON, 30 templates, web + mobile UI, i18n | 2026-02-17 | `MAINTENANCE_REMINDERS_PLAN.md` |
| **Project Planner Sprints 1-6** — AI project planning, intake interviews, plan modification | 2026-02-16 | `PROJECT_PLANNER_PLAN.md` |

---

## File Index

### Active Plans
| File | Purpose |
|------|---------|
| `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` | Push sending (Phase 1), Apple Sign-In (Phase 3) — Phase 2 done |
| `PROJECT_PLANNER_PLAN.md` | Project planner — remaining Sprint 7 + Phase 6 |
| `HYBRID_TOOL_LAYER_PHASE5_MCP_ADAPTER.md` | MCP adapter (deferred) |
| `scheduling/` | Scheduling feature (3 files: plan, architecture, UX) |

### Completed Reference
| File | Purpose |
|------|---------|
| `AUDIT_AI_ANALYSIS_PLAN.md` | Implementation reference (complete) |
| `SP_REGISTRATION_PLAN.md` | Implementation reference (all 5 phases complete) |
| `EVENT_DRIVEN_ARCHITECTURE_PLAN.md` | Implementation reference (all 7 phases complete) |
| `LOGGING_AUDITING_PLAN.md` | Implementation reference |
| `MAINTENANCE_REMINDERS_PLAN.md` | Implementation reference |
| `AI_GUARDRAILS_PLAN.md` | Implementation reference + pending migrations + deferred items |
| `MCP_OAUTH_PLAN.md` | Implementation reference + deferred Phase 2 |
| `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` | Decision doc + Tier 1 action items |
| `hover-tooltips-plan.md` | Implementation reference (complete) |

### QA & Testing
| File | Purpose |
|------|---------|
| `MANUAL_TEST_PLAN.md` | Test plan template for all 4 personas |
| `QA_HARDCODED_CONTENT.md` | Pre-launch content checklist (P0 resolved, P1/P2 open) |
| `QA_REPORT_2026-02-18.md` | QA sweep — admin + anonymous tested, customer/SP need re-test |
| `manual-test-report.md` | Full manual test report (2 Major, 4 Minor, 1 Info) |
