# Projulous — Consolidated Plan & TODO

> **Last Updated**: 2026-02-21

---

## Pre-Launch Bugs & QA Fixes

Open issues from QA reports (manual-test-report.md, QA_REPORT_2026-02-18.md).

### High Priority

| # | Issue | Source | Project | Effort |
|---|-------|--------|---------|--------|
| 1 | **Admin guard too permissive** — any admin permission grants access to ALL admin pages. Need per-route permission checks. | QA-MAJ-1/2 | web | 3h |
| 2 | ~~**AuthMethodIcons shows "Password" for OAuth-only users**~~ — FIXED: backend now returns `hasPassword` boolean, detail page uses it | QA-MAJ-3 | web + svc | done |
| 3 | **Browse All Services shows only 1 vendor type** — only Plumbing is PUBLISHED. Create/publish vendor pages for categories on home page, or filter carousel. | MT-MAJ-1 | DB ops / web | 2h |
| 4 | ~~**Vendor page shows 11% Satisfaction Rate**~~ — test data only, ignored | MT-MAJ-2 | svc | n/a |

### Medium Priority

| # | Issue | Source | Project | Effort |
|---|-------|--------|---------|--------|
| 5 | **Seed help center content** — articles, categories, FAQs all empty | QA-MED-1 | DB ops | 1h |
| 6 | **Seed project showcase** — `/projects` page is empty | QA-MED-2 | DB ops | 1h |
| 7 | ~~**Missing BILLING i18n key**~~ — FIXED: translations exist in all 3 languages | MT-MIN-2 | web | done |

### Low Priority

| # | Issue | Source | Project | Effort |
|---|-------|--------|---------|--------|
| 8 | ~~**Sidebar shows customer items to anonymous users**~~ — FIXED: `handleProtectedNavigation` redirects to login | MT-MIN-1 | web | done |
| 9 | **SP Certification 403 error** — raw error banner for non-admin SP members instead of friendly message | MT-MIN-3 | web | 30m |
| 10 | ~~**Ideas page redirect for anonymous**~~ — FIXED: shows sign-in prompt with explanation | MT-MIN-4 | web | done |
| 11 | ~~**Contact page "Start Chat" non-functional**~~ — FIXED: removed live chat card, ticket + email remain | QA-LOW-1 | web | done |
| 12 | **Community Resources links go to "#"** — 4 cards (Guides, Videos, Forum, Status) are dead links | QA-LOW-2 | web | 30m |
| 13 | ~~**Plumbing vendor page test FAQ data**~~ — test data only, ignored | QA-LOW-3 | DB ops | n/a |
| 14 | ~~**FAQ modal hardcodes dark theme**~~ — FIXED: FAQ + Showcase modals now have proper light/dark variants | QA-MIN-3 | web | done |
| 15 | **Hover tooltips** — ~60 icon-only elements across ~30 files need `title` attributes | hover-tooltips-plan.md | web | 1.5h |

### Pending Migrations (AI Guardrails)

Two schema changes from AI Guardrails Tier 4 require migrations before deployment:
1. `CertificationStatusENUM` — add `AI_RECOMMENDED` value (+ `CertificationLogActionENUM`, `NotificationTypeENUM`)
2. `DiscoverySourceENUM` — new Postgres enum type + `discoverySource` column on `ServiceProviders` table

### Personas Not Yet Fully Tested

Customer and Service Provider personas were only partially tested via Chrome extension. Need full re-test of ~18 page areas (see QA_REPORT_2026-02-18.md for list).

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
**Status**: NOT STARTED (3 independent phases)

| Phase | Description | Effort |
|-------|-------------|--------|
| 1 | Backend push notification sending via expo-server-sdk (PushNotificationService) | 4-6h |
| 2 | Multi-session refresh tokens (RefreshTokenSession entity, per-device hashes) | 6-8h |
| 3 | Complete Apple Sign-In (credentials, native iOS, web feature flag) | 4-6h |

### SP Registration & Onboarding
**File**: `SP_REGISTRATION_PLAN.md`
**Status**: NOT STARTED (5 phases)

| Phase | Description | Effort |
|-------|-------------|--------|
| 1 | TOS/Privacy acceptance (PolicyAcceptance entity, re-acceptance flow) | 1-2 days |
| 2 | Claim token system (AI-discovered SP association via email link) | 1-2 days |
| 3 | Self-service SP claim (search unclaimed SPs, email verification, admin fallback) | 2-3 days |
| 4 | SP onboarding wizard (profile, offerings, tier selection) | 2-3 days |
| 5 | OAuth registration improvements (TOS + claim token in OAuth flow) | 1 day |

### Event-Driven Architecture Refactor
**File**: `EVENT_DRIVEN_ARCHITECTURE_PLAN.md`
**Status**: NOT STARTED (7 phases)

Key issues to fix: 6+ services directly call NotificationService, 5 circular dependencies, 30+ unhandled event types, ~15 methods lack transactions, 11 services emit no events.

| Phase | Description |
|-------|-------------|
| 1 | Foundation: SharedEventsModule singleton, type-safe handlers, dead code cleanup |
| 2 | Notification routing via events |
| 3 | Event-driven email, audit, AI |
| 4 | Missing events (auth, conversation, admin) |
| 5 | Transaction safety |
| 6 | Circular dependency elimination |
| 7 | Cross-domain entity decoupling |

### Project Planner — Remaining Work
**File**: `PROJECT_PLANNER_PLAN.md`
**Status**: Sprints 1-6 COMPLETE. Sprint 7 + Phase 6 NOT STARTED.

| Item | Description |
|------|-------------|
| Sprint 7 | Notifications & Polish (plan ready notifications, phase completion, etc.) |
| Phase 6 | Collaborator Auth & Access (invite collaborators, shared project editing) |

### Audit Log AI Analysis
**File**: `AUDIT_AI_ANALYSIS_PLAN.md`
**Status**: NOT STARTED

"PJ Analyze" mode for audit logs admin page — select rows, send to Gemini for summarization, pattern detection, and troubleshooting suggestions. ~5-7h estimated.

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

---

## Deferred / Low Priority

| Item | Notes |
|------|-------|
| Boilerplate try/catch decorator | Cosmetic, 200+ methods, high risk-to-reward |
| ~20+ `any` types in codebase | Fix opportunistically |
| localStorage permissions UI exposure | Backend guards are solid, cosmetic UI-only |
| AI Guardrails Tier 5 (prompt eval framework, image moderation, feedback cost optimization) | See `AI_GUARDRAILS_PLAN.md` |
| AI Guardrails deferred items (auth gate for discovery, token/cost tracking, off-topic pre-filter, periodic cleanup CRON) | See `AI_GUARDRAILS_PLAN.md` |
| DB log separation (Tier 2-3) | Partition at 500K+ rows, separate DB at 10M+ rows. See `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` |
| MCP OAuth multi-provider (Apple + Facebook) | See `MCP_OAUTH_PLAN.md` Phase 2 |

---

## Recently Completed

| Feature | Date | Plan File |
|---------|------|-----------|
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
| `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` | Push sending, multi-session auth, Apple Sign-In |
| `SP_REGISTRATION_PLAN.md` | SP registration, onboarding, claim flow |
| `EVENT_DRIVEN_ARCHITECTURE_PLAN.md` | Event system refactor (7 phases) |
| `PROJECT_PLANNER_PLAN.md` | Project planner — remaining Sprint 7 + Phase 6 |
| `AUDIT_AI_ANALYSIS_PLAN.md` | AI analysis feature for audit logs |
| `HYBRID_TOOL_LAYER_PHASE5_MCP_ADAPTER.md` | MCP adapter (deferred) |
| `hover-tooltips-plan.md` | Add title attrs to ~60 icon-only elements |
| `scheduling/` | Scheduling feature (3 files: plan, architecture, UX) |

### Completed Reference
| File | Purpose |
|------|---------|
| `LOGGING_AUDITING_PLAN.md` | Implementation reference |
| `MAINTENANCE_REMINDERS_PLAN.md` | Implementation reference |
| `AI_GUARDRAILS_PLAN.md` | Implementation reference + pending migrations + deferred items |
| `MCP_OAUTH_PLAN.md` | Implementation reference + deferred Phase 2 |
| `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` | Decision doc + Tier 1 action items |

### QA & Testing
| File | Purpose |
|------|---------|
| `MANUAL_TEST_PLAN.md` | Test plan template for all 4 personas |
| `QA_HARDCODED_CONTENT.md` | Pre-launch content checklist (P0 resolved, P1/P2 open) |
| `QA_REPORT_2026-02-18.md` | QA sweep — admin + anonymous tested, customer/SP need re-test |
| `manual-test-report.md` | Full manual test report (2 Major, 4 Minor, 1 Info) |
