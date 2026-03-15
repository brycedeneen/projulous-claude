# Projulous — Master Plan

> **Last Updated**: 2026-03-15

---

## Active Plans — Ready to Build

### 1. Web-to-Mobile Feature Parity (IN PROGRESS)
**File**: `WEB_TO_MOBILE_FEATURE_GAP_PLAN.md`
**Execution**: `UNIFIED_EXECUTION_PLAN.md`
**Status**: Sprints 1 & 3 COMPLETE. Remaining: SP Offerings (Sprint 2 partial), Sprint 4 (customer enhancements), Sprint 5 (discovery)

Most SP mobile features were built but the gap plan wasn't updated. The remaining 9 mobile items are tracked in `UNIFIED_EXECUTION_PLAN.md`.

| Sprint | Focus | Status |
|--------|-------|--------|
| 1 | SP Foundation (onboarding, registration, dashboard, nav) | **COMPLETE** |
| 2 | SP Management (offerings, team, billing, certification) | **Mostly done** — offerings CRUD + billing wiring remain |
| 3 | Support & Help (tickets, help center) | **COMPLETE** |
| 4 | Customer Enhancements (maintenance overview, ideas, billing, quotes) | NOT STARTED (~7d) |
| 5 | Discovery (browse services, vendor pages, SP detail) | NOT STARTED (~5-6d) |

### 2. SP Showcase Self-Publishing (HIGH)
**File**: `SP_SHOWCASE_SELF_PUBLISHING_PLAN.md`
**Status**: NOT STARTED

SP self-publishing of portfolio showcase posts (Pro/Pinnacle tier). S3 photo uploads, AI writing feedback, draft/publish workflow. Replaces hardcoded homepage showcase with real data.

| Phase | Description | Effort |
|-------|-------------|--------|
| 1 | Shared DTO: ShowcaseProjectPhoto entity, ShowcaseProjectStatusENUM | 2h |
| 2 | Backend: S3 photo uploads, SP CRUD endpoints, AI writing feedback | 6-8h |
| 3 | Web SP portal: showcase management UI | 6-8h |
| 4 | Homepage wiring: replace static showcase with real API data | 3-4h |
| 5 | Permissions seeding (4 new permissions) | 30m |

### 3. Project Planner — Sprint 7 (MEDIUM)
**File**: `PROJECT_PLANNER_PLAN.md`
**Status**: Sprints 1-6 DONE, Phase 6 DONE, Sprint 7 NOT STARTED

| Item | Description |
|------|-------------|
| Sprint 7 | Notifications & Polish (plan ready notifications, phase completion alerts, drag-to-reorder phases, quote management per phase) |

### 4. PJ for Service Providers (LARGE — needs implementation plan)
**File**: `PJ_FOR_SERVICE_PROVIDERS_PLAN.md`
**Status**: Design doc complete (56 use cases), no implementation plan

Top quick wins that need no new entities: offering description generator, quote response drafter, customer message reply drafter, profile completeness coach, weekly business digest. Requires implementation plan prioritizing the 15 quick wins.

### 5. Styled Emails — Remaining Phases (LOW)
**File**: `STYLED_EMAILS_PLAN.md`
**Status**: Phase 1 DONE (8 templates + generic-branded), Phases 2-3 deferred

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Auth & Core (8 templates) | **DONE** |
| 2 | SP Certification branded wrapper | Deferred — low priority |
| 3 | Future billing/digest email templates | Blocked on billing feature |

---

## Seed Scripts (ready to run)

| Script | Description | Status |
|--------|-------------|--------|
| `seed_feature_flags.sql` | Feature flag permissions + initial LLM_ONLY_CLASSIFICATION flag | Ready to run |
| `seed_sp_review_permissions.sql` | 6 SP review permissions assigned to CUSTOMER, SP, SUPER_ADMIN | Ready to run |

---

## Completed

| Item | File | Notes |
|------|------|-------|
| Lead Management | `LEAD_MANAGEMENT_WRITEUP.md` | Full stack: entity, backend CRUD + CRON follow-ups + expiration, web admin pages, mobile admin (leads tab), public follow-up page, quote-request email integration |
| Styled Emails Phase 1 | `STYLED_EMAILS_PLAN.md` | 10 MJML templates, EmailTemplateService, preview controller, partials, generic-branded wrapper |
| Feature Flags | — | Entity, full CRUD, web admin page, mobile admin screen, seed SQL written |
| SP Reviews | — | Full review system: SpReview + SpReviewResponse + SpReviewFlag entities, moderation service, web admin dashboard + detail pages, mobile admin screens, seed SQL written |
| Push Notification Sending | `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` Phase 1 | PushNotificationService (expo-server-sdk), fire-and-forget, preference checking, integrated into NotificationService |
| Multi-Session Refresh Tokens | `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` Phase 2 | RefreshTokenSession entity, per-session rotation, session cleanup CRON, platform tracking |
| Apple Sign-In | `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` Phase 3 | Backend strategy + native endpoint, mobile native iOS + Android browser fallback, web flag enabled. Remaining: Apple Developer credential setup (manual, not code) |
| Project Collaborator Invite | `PROJECT_COLLABORATOR_INVITE_PLAN.md` | SHA256 tokens, email template, acceptance page, CRON expiry, resend/cancel, public endpoints — all done |
| Mobile SP Foundation (Sprint 1) | `WEB_TO_MOBILE_FEATURE_GAP_PLAN.md` | SP onboarding wizard, SP registration, SP dashboard/home screen, SP nav in settings — all built |
| Mobile SP Team + Certification (Sprint 2 partial) | `WEB_TO_MOBILE_FEATURE_GAP_PLAN.md` | Team management (list, detail, invite), certification (status, questions, history) — done. Offerings + billing wiring remain. |
| Mobile Support & Help (Sprint 3) | `WEB_TO_MOBILE_FEATURE_GAP_PLAN.md` | Tickets (list, detail, create) for both customer and SP, help center (index, category, article) — all built |
| Role-Based Page Access | `ROLE_BASED_PAGE_ACCESS_PLAN.md` | `routeAccessConfig.ts`, `roleGuard.layout.tsx`, sidebar integration, 27 tests |
| Redbrick Admin Mobile App | `REDBRICK_ADMIN_MOBILE_PLAN.md` | Dashboard, support tickets, activity (audit + AI logs), leads tab, settings, "More" menu (users, roles, SPs, SP review, claims, ideas, help center, vendor pages, billing, feature flags, notifications). Remaining: i18n polish, branding refinement |
| DB Pre-Scaling Tier 1 | `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` | Connection pool sizes (15 write / 10 read), LogRetentionCron (daily batched deletes), SessionCleanupCron |

---

## Pre-Scaling (only matters for multi-instance deploys)

| # | Item | Project | Effort | Status |
|---|------|---------|--------|--------|
| 1 | **Permissions caching** — cache in JWT or short-lived Redis | svc | 4h | not started |
| 2 | **OAuth code store -> Redis/DB** — currently in-memory Map (60s TTL) | svc | 3h | not started |
| 3 | **Discovery cache -> Redis** — currently in-memory Map (5-min cooldown) | svc | 3h | not started |
| 4 | ~~DB log retention CRON~~ | svc | — | **DONE** |
| 5 | ~~Explicit connection pool sizes~~ | svc | — | **DONE** |
| 6 | **Autovacuum tuning** — aggressive vacuum for log tables | migration | 30m | not started |

---

## Deferred (post-launch / V2)

| Item | File | Notes |
|------|------|-------|
| Appliance Diagnostic Agent | `APPLIANCE_DIAGNOSTIC_AGENT_PLAN.md` | V2 — infra exists from concierge build, mostly a prompt swap |
| MCP Adapter | `HYBRID_TOOL_LAYER_PHASE5_MCP_ADAPTER.md` | Post-launch — expose tool registry via MCP |
| Web Push Notifications | `WEB_PUSH_NOTIFICATIONS_PLAN.md` | Needs SSE first (~10h) |
| Scheduling / Booking | `scheduling/` (3 files) | Future product decision (~16 weeks) |
| Stripe Billing | — | Future product decision (8-12 weeks) |
| SP Quote Request/Response | — | Real quote flow: customer sends request, SP responds |
| AI Guardrails Tier 5 | — | Prompt eval framework, image moderation, feedback cost optimization |
| DB log separation (Tier 2-3) | `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` | Partition at 500K+ rows, separate DB at 10M+ |

---

## File Index

| File | Purpose | Status |
|------|---------|--------|
| `UNIFIED_EXECUTION_PLAN.md` | Sequenced execution plan for remaining 11 features (19 tasks) | **ACTIVE** |
| `LEAD_MANAGEMENT_WRITEUP.md` | Lead management system documentation | **COMPLETE** |
| `STYLED_EMAILS_PLAN.md` | Styled email templates (MJML) | **Phase 1 COMPLETE** |
| `WEB_TO_MOBILE_FEATURE_GAP_PLAN.md` | Web-to-mobile feature parity (22 gaps, 5 sprints) | Active |
| `SP_SHOWCASE_SELF_PUBLISHING_PLAN.md` | SP self-publishing showcase (5 phases) | Active |
| `PJ_FOR_SERVICE_PROVIDERS_PLAN.md` | PJ AI for SPs (56 use cases, needs impl plan) | Active |
| `PROJECT_PLANNER_PLAN.md` | Project planner remaining (Sprint 7) | Active |
| `PROJECT_COLLABORATOR_INVITE_PLAN.md` | Collaborator invite workflow | **COMPLETE** |
| `ROLE_BASED_PAGE_ACCESS_PLAN.md` | Frontend route guards + sidebar config | **COMPLETE** |
| `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` | Push sending + multi-session + Apple Sign-In | **COMPLETE** (credentials manual) |
| `REDBRICK_ADMIN_MOBILE_PLAN.md` | Admin mobile app | **COMPLETE** (polish remaining) |
| `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` | Decision doc — Tier 1 done, Tier 2-3 deferred | Tier 1 **COMPLETE** |
| `seed_feature_flags.sql` | Feature flag permissions seed | Ready to run |
| `seed_sp_review_permissions.sql` | SP review permissions seed | Ready to run |
| `APPLIANCE_DIAGNOSTIC_AGENT_PLAN.md` | Diagnostic AI prompt | Deferred V2 |
| `HYBRID_TOOL_LAYER_PHASE5_MCP_ADAPTER.md` | MCP adapter | Deferred |
| `WEB_PUSH_NOTIFICATIONS_PLAN.md` | Browser push notifications | Deferred |
| `scheduling/` | Scheduling feature (3 files) | Deferred |
