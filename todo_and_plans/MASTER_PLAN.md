# Projulous — Master Plan

> **Last Updated**: 2026-02-28

---

## Active Plans — Ready to Build

### 0. Web-to-Mobile Feature Parity (CRITICAL)
**File**: `WEB_TO_MOBILE_FEATURE_GAP_PLAN.md`
**Status**: NOT STARTED

Comprehensive gap analysis: 22 significant features exist in projulous-web but are missing from projulous-mobile. The biggest gap is the entire SP experience (onboarding, dashboard, offerings, team, billing, certification, tickets — all missing). Also missing: help center, support tickets, maintenance overview, ideas board, browse services, vendor landing pages, SP detail pages, and more.

| Sprint | Focus | Items | Effort | Priority |
|--------|-------|-------|--------|----------|
| 1 | SP Foundation (onboarding, registration, dashboard, nav) | 5 | ~10d | P0 |
| 2 | SP Management (offerings, team, billing, certification) | 4 | ~10d | P0 |
| 3 | Support & Help (push notifications, tickets, help center) | 3 | ~8d | P0/P1 |
| 4 | Customer Enhancements (maintenance overview, ideas, billing, quotes) | 4 | ~7d | P1/P2 |
| 5 | Discovery (browse services, vendor pages, SP detail, showcase) | 4 | ~6d | P2/P3 |
| **Total** | | **19 items** | **~35-46d** | |

### 1. SP Showcase Self-Publishing (HIGH)
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

### 3. Push Notifications + Apple Sign-In (MEDIUM)
**File**: `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md`
**Status**: Phase 2 DONE, Phases 1 & 3 NOT STARTED

| Phase | Description | Effort | Status |
|-------|-------------|--------|--------|
| 1 | Backend push sending via expo-server-sdk (PushNotificationService) | 4-6h | not started |
| 2 | ~~Multi-session refresh tokens~~ | — | **DONE** |
| 3 | Apple Sign-In (credentials, native iOS, web feature flag) | 4-6h | not started |

### 4. Project Planner — Remaining Work (MEDIUM)
**File**: `PROJECT_PLANNER_PLAN.md`
**Status**: Sprints 1-6 DONE, Phase 6 DONE, Sprint 7 NOT STARTED

| Item | Description |
|------|-------------|
| Sprint 7 | Notifications & Polish (plan ready notifications, phase completion alerts) |

### 5. Redbrick Admin Mobile App (NEEDS AUDIT)
**File**: `REDBRICK_ADMIN_MOBILE_PLAN.md`
**Status**: App exists with some features, but plan checkboxes unchecked. Needs comparison against actual app state to determine remaining work.

---

## Completed

| Item | File | Notes |
|------|------|-------|
| Project Collaborator Invite Workflow | `PROJECT_COLLABORATOR_INVITE_PLAN.md` | SHA256 tokens, email, acceptance page, CRON expiry, resend/cancel — all done |
| Role-Based Page Access | `ROLE_BASED_PAGE_ACCESS_PLAN.md` | `routeAccessConfig.ts`, `roleGuard.layout.tsx`, sidebar integration, 27 tests |

---

## Pre-Scaling (only matters for multi-instance deploys)

| # | Item | Project | Effort |
|---|------|---------|--------|
| 1 | **Permissions caching** — cache in JWT or short-lived Redis | svc | 4h |
| 2 | **OAuth code store -> Redis/DB** — currently in-memory Map (60s TTL) | svc | 3h |
| 3 | **Discovery cache -> Redis** — currently in-memory Map (5-min cooldown) | svc | 3h |
| 4 | **DB log retention CRON** — batched deletes for AuditLogs (12mo) + AIInteractionLogs (6mo) | svc | 3h |
| 5 | **Explicit connection pool sizes** — add max to write/read DataSources | svc | 15m |
| 6 | **Autovacuum tuning** — aggressive vacuum for log tables | migration | 30m |

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
| Boilerplate try/catch decorator | — | Cosmetic, 200+ methods, low ROI |

---

## File Index

| File | Purpose |
|------|---------|
| `WEB_TO_MOBILE_FEATURE_GAP_PLAN.md` | Web-to-mobile feature parity (22 gaps, 5 sprints) |
| `PROJECT_COLLABORATOR_INVITE_PLAN.md` | Collaborator invite workflow — **COMPLETE** |
| `SP_SHOWCASE_SELF_PUBLISHING_PLAN.md` | SP self-publishing showcase (5 phases) |
| `ROLE_BASED_PAGE_ACCESS_PLAN.md` | Frontend route guards + sidebar config — **COMPLETE** |
| `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` | Push sending (Phase 1) + Apple Sign-In (Phase 3) |
| `PROJECT_PLANNER_PLAN.md` | Project planner remaining (Sprint 7 + Phase 6) |
| `REDBRICK_ADMIN_MOBILE_PLAN.md` | Admin mobile app (needs status audit) |
| `AUDIT_LOG_DB_SEPARATION_EVALUATION.md` | Decision doc — Tier 1 pre-scaling items |
| `APPLIANCE_DIAGNOSTIC_AGENT_PLAN.md` | Diagnostic AI prompt (deferred V2) |
| `HYBRID_TOOL_LAYER_PHASE5_MCP_ADAPTER.md` | MCP adapter (deferred post-launch) |
| `WEB_PUSH_NOTIFICATIONS_PLAN.md` | Browser push notifications (deferred) |
| `scheduling/` | Scheduling feature (3 files, deferred) |
