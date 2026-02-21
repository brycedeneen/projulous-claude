# AI Guardrails & Security Hardening Plan

**Last Updated**: 2026-02-19
**Status**: Tiers 1-4 implemented (except deferred items). Tier 5 deferred.

## Executive Summary

An audit of all 15 AI/LLM usage areas across Projulous identified security gaps in prompt injection defense, content filtering, rate limiting, data isolation, and automated trust decisions. This plan organizes remediation into 5 priority tiers with pros/cons for each change.

---

## Implementation Status Summary

| Item | Status | Files Changed |
|------|--------|---------------|
| **Tier 1** | | |
| 1.1A Enhanced sanitization | DONE | `sanitize.util.ts` |
| 1.1B Sandwich defense | DONE | `prompts.config.ts` |
| 1.1C Fix providerComparisonQA input | DONE | `prompts.config.ts`, `chat.service.ts` |
| 1.2A Rate limiting (15/min auth, 5/min unauth) | DONE | `chat.controller.ts`, `conversation.controller.ts`, `appliancePhotoExtract.controller.ts`, `feedbackSubmission.controller.ts` |
| 1.2B Auth gate for expensive ops | DEFERRED | User decided anonymous discovery is core product value |
| 1.2C Token/cost tracking | DEFERRED | |
| 1.3 Auth gate for discovery | DEFERRED | Same as 1.2B |
| **Tier 2** | | |
| 2.1A Domain constraint prompts | DONE | `prompts.config.ts` (5 prompts updated) |
| 2.1B Off-topic pre-filter | DEFERRED | Domain constraints in prompts deemed sufficient for now |
| 2.2A Output validator | DONE | `outputValidator.util.ts` (new), integrated in `chat.service.ts`, `projectPlanner.service.ts` |
| 2.2B Response length limits | DONE | Context-specific limits: Q&A 1000, scoping 500, phase Q&A 1500, quote 2000 |
| **Tier 3** | | |
| 3.1 Data isolation audit | DONE | Confirmed all areas properly scoped |
| 3.2A Conversation ownership validation | DONE | `conversation.service.ts` (`assertConversationOwnership`), `chat.service.ts` |
| 3.2B Audit logging | DONE | `aiAuditLogger.util.ts` (new), integrated in `findService.service.ts`, `projectPlanner.service.ts`, `spCertificationAiReview.service.ts`, `spDataEnrichment.service.ts` |
| **Tier 4** | | |
| 4.1A Remove auto-certification | DONE | `spCertificationAiReview.service.ts`, `CertificationStatusENUM`, `CertificationLogActionENUM`, `NotificationTypeENUM` |
| 4.1B Move cert prompt to registry | DONE | `prompts.config.ts`, `prompt.service.ts`, `spCertificationAiReview.service.ts` |
| 4.2A AI_DISCOVERED flag | DONE | `DiscoverySourceENUM` (new), `serviceProvider.entity.ts`, `findService.service.ts`, `auth.service.ts` |
| 4.2B Display disclaimer for AI-discovered | DONE | `ProviderCard.tsx`, translation files (en/es/fr) |
| 4.2C Periodic cleanup CRON | DEFERRED | |
| 4.3A Soft-delete + versioning | DEFERRED | Opted for simpler 4.3B instead |
| 4.3B Phase count validation | DONE | `chat.service.ts`, `projectPlanner.service.ts` |
| **Tier 5** | | |
| 5.1 Prompt eval framework | DEFERRED | |
| 5.2 Image content moderation | DEFERRED | |
| 5.3 Feedback cost optimization | DEFERRED | |

### Pending: Database Migrations

Two schema changes require migrations before deployment:
1. `CertificationStatusENUM` - add `AI_RECOMMENDED` value (also `CertificationLogActionENUM`, `NotificationTypeENUM`)
2. `DiscoverySourceENUM` - new Postgres enum type + `discoverySource` column on `ServiceProviders` table (default `MANUAL`, nullable)

---

## Tier 1: Critical Security (Implement First)

### 1.1 Enhanced Input Sanitization & Prompt Injection Defense

**Problem**: Current `SanitizeUtil.sanitizeUserInput()` only strips HTML tags and backticks with a 500-char limit. No defense against role-override attacks ("ignore your instructions"), instruction injection, or prompt leakage attempts.

**Changes**:

#### A. Upgrade `SanitizeUtil.sanitizeUserInput()` -- DONE

Added to `projulous-svc/src/utils/sanitize.util.ts`:
- `SanitizeContext` type (`'standard' | 'strict'`)
- Injection phrase stripping (15+ phrases: "ignore previous instructions", "you are now", "system:", etc.)
- Base64 block regex stripping
- Excessive special character regex stripping
- Backward-compatible: second parameter accepts `SanitizeContext | number`

| Pros | Cons |
|------|------|
| Blocks the most common injection patterns | Regex-based blocking is an arms race; determined attackers can find workarounds |
| Low effort, high impact | Could false-positive on legitimate input (e.g., user says "ignore previous estimate") |
| Centralized - one file change protects all endpoints | Needs ongoing maintenance as new attack patterns emerge |

#### B. Sandwich Defense Pattern for All Free-Text LLM Prompts -- DONE

Added sandwich defense reminders to 5 prompts in `prompts.config.ts`:
- `providerComparisonQA`
- `projectPhaseQA`
- `quoteComparison`
- `projectScopingInterview`
- `feedbackOptimizeIdea`

| Pros | Cons |
|------|------|
| Industry-standard defense that significantly reduces injection success rate | Increases token count (and cost) on every call |
| Simple to implement in the prompt registry | Not 100% effective - sophisticated attacks can still bypass |
| Works well with Gemini's system instruction separation | May slightly increase latency |

#### C. Fix User Input Placement in `providerComparisonQA` -- DONE

Removed user question from system instruction template. User input now exclusively in `contents` field.

| Pros | Cons |
|------|------|
| Eliminates the most dangerous injection surface in the codebase | Requires reworking the prompt template |
| Aligns with LLM provider best practices (system vs user separation) | Need to verify response quality doesn't degrade |

---

### 1.2 Rate Limiting on AI Endpoints

#### A. Tiered Rate Limiting -- DONE

Implemented with `@nestjs/throttler`:

| Endpoint | Auth'd Users | Unauth'd Users | Window |
|----------|-------------|-----------------|--------|
| `/v1/projulous-ai/chat` | 15 req/min | 5 req/min | 1 min |
| `/v1/projulous-ai/conversations` | 15 req/min | 5 req/min | 1 min |
| Appliance photo extraction | 10 req/hour | N/A (auth required) | 1 hour |
| Feedback submission (AI pipeline) | 5 req/hour | N/A (auth required) | 1 hour |

#### B. Require Authentication for Expensive Operations -- DEFERRED

**Decision**: User decided NOT to gate discovery behind auth. Anonymous users finding service providers is core product value. Will monitor and gate if abuse is detected.

#### C. Token/Cost Tracking -- DEFERRED

---

### 1.3 Require Authentication for Chat AI Access Beyond Classification -- DEFERRED

**Decision**: Same as 1.2B. Anonymous discovery is core product value.

---

## Tier 2: Content Safety & Topic Enforcement (High Priority)

### 2.1 Domain-Constrained System Prompts

#### A. Add Domain Boundary Instructions to All User-Facing Prompts -- DONE

Added `CRITICAL CONSTRAINTS` block to 5 prompts:
- `providerComparisonQA`
- `projectPhaseQA`
- `quoteComparison`
- `projectScopingInterview`
- `feedbackOptimizeIdea`

Constraints include: home-services-only domain, no code generation, no prompt revelation, no persona changes.

| Pros | Cons |
|------|------|
| Directly addresses the "unintended use" concern | Increases prompt length and token cost |
| LLMs are generally good at following domain constraints | Overly strict constraints could reject legitimate edge-case questions |
| Easy to implement - just prompt text changes | Requires testing to tune the boundary |

#### B. Off-Topic Detection Pre-Filter -- DEFERRED

**Decision**: Domain constraints in prompts (2.1A) deemed sufficient. Will add pre-filter if testing reveals constraints alone are insufficient.

---

### 2.2 Output Validation for Free-Text Responses

#### A. Create `OutputValidator` Utility -- DONE

New file: `projulous-svc/src/utils/outputValidator.util.ts`

Features:
- Strips markdown code blocks
- Strips HTML tags
- Filters URLs not in `allowedUrls` list (preserves provider website URLs)
- Detects prompt leakage patterns (system prompt fragments) and replaces with fallback
- Configurable `maxLength` per context
- 50 tests in spec file

Integrated in:
- `chat.service.ts` (provider Q&A responses)
- `projectPlanner.service.ts` (scoping interview, phase Q&A, quote comparison)

#### B. Response Length Limits -- DONE

Context-specific limits applied via `OutputValidator.validateFreeTextResponse()`:

| Context | Max Length |
|---------|-----------|
| Provider Q&A | 1000 chars |
| Phase Q&A | 1500 chars |
| Quote Comparison | 2000 chars |
| Scoping Interview | 500 chars |

---

## Tier 3: Data Isolation & Tenant Boundaries (Important)

### 3.1 Audit Findings: Current State -- DONE (Informational)

| Area | Isolation Status | Details |
|------|-----------------|---------|
| Conversations | **GOOD** | All queries filter by `user.sub` (userId) |
| Project Plans | **GOOD** | Plan phases linked to user-owned `CustomerProject` |
| Appliance Photos | **GOOD** | Linked to user-owned appliances |
| Feedback | **GOOD** | Linked to `createdBy` user ID |
| Provider Discovery | **BY DESIGN - SHARED** | Providers are shared resources, no user data leaks |
| Chat History | **GOOD** | Messages linked to user-scoped conversations |

### 3.2 Remaining Gaps

#### A. Conversation Ownership Validation Helper -- DONE

Added `assertConversationOwnership(conversationId, userId)` to `ConversationService`:
- Checks both conversation existence and participant membership via `ConversationParticipant` join table
- Throws `ForbiddenException` with vague message to prevent info leakage
- Integrated into `ChatService.handleChatMessage()` and `handleSelectProviders()`
- 4 tests in spec file

#### B. Audit Logging for Sensitive AI Operations -- DONE

New file: `projulous-svc/src/utils/aiAuditLogger.util.ts`

`AIAuditAction` enum:
- `PROVIDER_DISCOVERED` - when findService creates a new SP
- `PROVIDER_ENRICHED` - when spDataEnrichment updates SP data
- `PLAN_CREATED` - when projectPlanner creates a new plan
- `PLAN_MODIFIED` - when projectPlanner modifies existing plan
- `SP_CERTIFICATION_REVIEWED` - when AI reviews SP certification email
- `SP_AI_RECOMMENDED` - when AI recommends certification

Integrated in: `findService.service.ts`, `projectPlanner.service.ts`, `spCertificationAiReview.service.ts`, `spDataEnrichment.service.ts`

---

## Tier 4: Automated Trust Decisions (Important)

### 4.1 SP Certification Auto-Approval

#### A. Remove Auto-Certification, Require Human Approval -- DONE

Changes:
- Removed all auto-certification logic from `spCertificationAiReview.service.ts`
- Now sets `certificationStatus = AI_RECOMMENDED` instead of `CERTIFIED`
- Does NOT set `verifiedStatus` or certification dates
- Creates admin notification via `NotificationService`
- Notifies associated SP users about review completion
- Added `AI_RECOMMENDED` to `CertificationStatusENUM`, `CertificationLogActionENUM`
- Added `CERTIFICATION_AI_RECOMMENDED` to `NotificationTypeENUM` + category mapping
- 16 tests pass in spec file

#### B. Move SP Certification Prompt to the Prompt Registry -- DONE

Moved hardcoded prompt from `spCertificationAiReview.service.ts` to `prompts.config.ts` as `certificationEmailReview`. Now uses `PromptService.getCertificationEmailReviewPrompt()`.

---

### 4.2 Provider Discovery Auto-Write Safeguards

#### A. Add `AI_DISCOVERED` Flag -- DONE

New `DiscoverySourceENUM`:
- `MANUAL` - admin-created (default)
- `AI_DISCOVERED` - found via Gemini + Google Search
- `SELF_REGISTERED` - provider signed up themselves

Added `discoverySource` column to `ServiceProvider` entity (nullable, default `MANUAL`).
- `findService.service.ts` sets `AI_DISCOVERED` when creating providers
- `auth.service.ts` sets `SELF_REGISTERED` in `registerServiceProviderUser()`
- Added to `CreateServiceProviderDTO`, `UpdateServiceProviderDTO`, `ServiceProviderResultDto`

#### B. Display Disclaimer for AI-Discovered Providers -- DONE

`ProviderCard.tsx` shows "Details sourced from web search" for AI_DISCOVERED + unverified providers. Translated in EN/ES/FR.

#### C. Periodic Cleanup Job -- DEFERRED

---

### 4.3 Project Plan Modification Safety

#### A. Soft-Delete + Versioning -- DEFERRED

Opted for simpler 4.3B instead. Consider for future iteration.

#### B. Phase Count Validation -- DONE

Added to `projectPlanner.service.ts` and `chat.service.ts`:
- If LLM response drops >50% of phases (minimum 3 phases), returns a warning marker
- Uses `PHASE_COUNT_WARNING_MARKER` in chat message for user confirmation
- `isPhaseCountConfirmation()` detects user approval
- `findOriginalModificationRequest()` retrieves the original request to re-apply with `forceApply: true`
- Extended `PlanModificationResult` with `pendingConfirmation`, `originalPhaseCount`, `newPhaseCount`
- 9 new tests

---

## Tier 5: Quality & Observability -- ALL DEFERRED

### 5.1 Prompt Evaluation Framework -- DEFERRED

Automated test cases for prompt quality (classification accuracy, off-topic rejection, injection resistance, multi-language).

### 5.2 Image Content Moderation for Appliance Photos -- DEFERRED

Pre-check using content moderation API before processing photos.

### 5.3 Feedback AI Pipeline Cost Optimization -- DEFERRED

Batch processing and prompt consolidation to reduce per-submission LLM calls.

---

## Implementation Priority & Effort Estimates

| Item | Priority | Status | Impact |
|------|----------|--------|--------|
| 1.1A Enhanced sanitization | P0 | DONE | High - blocks common injection vectors |
| 1.1B Sandwich defense | P0 | DONE | High - industry-standard defense |
| 1.1C Fix providerComparisonQA input placement | P0 | DONE | High - fixes most dangerous injection surface |
| 1.2A Rate limiting | P0 | DONE | High - prevents cost attacks |
| 1.2B Auth gate for expensive ops | P0 | DEFERRED | High - protects expensive AI operations |
| 1.2C Token/cost tracking | P1 | DEFERRED | Medium - observability |
| 1.3 Auth gate for discovery | P0 | DEFERRED | High - combines with 1.2B |
| 2.1A Domain constraint prompts | P1 | DONE | High - addresses core "unintended use" concern |
| 2.1B Off-topic pre-filter | P2 | DEFERRED | Medium - defense in depth |
| 2.2A Output validator | P1 | DONE | High - defense in depth for all free-text |
| 2.2B Response length limits | P1 | DONE | Medium - UX consistency |
| 3.2A Ownership validation helper | P1 | DONE | High - data isolation |
| 3.2B Audit logging | P2 | DONE | Medium - forensics |
| 4.1A Remove auto-certification | P1 | DONE | High - trust decision safety |
| 4.1B Move cert prompt to registry | P2 | DONE | Low - consistency |
| 4.2A AI_DISCOVERED flag | P2 | DONE | Medium - data attribution |
| 4.2B Display disclaimer | P2 | DONE | Medium - user transparency |
| 4.2C Periodic cleanup CRON | P2 | DEFERRED | Medium - data hygiene |
| 4.3B Phase count validation | P1 | DONE | Medium - data loss prevention |
| 5.1 Prompt eval framework | P3 | DEFERRED | High long-term - quality assurance |
| 5.2 Image moderation | P3 | DEFERRED | Low - edge case protection |
| 5.3 Feedback cost optimization | P3 | DEFERRED | Medium - cost reduction |

---

## Key Trade-offs Summary

| Decision | Trade-off |
|----------|-----------|
| Stricter input sanitization | May false-positive on legitimate input containing blocked phrases |
| Rate limiting unauthenticated users | May reduce conversion/engagement from new visitors |
| Domain constraints in prompts | May reject legitimate edge-case questions (tax, legal, insurance) |
| Remove auto-certification | Slower certification but safer trust decisions |
| Output validation stripping | Could remove legitimate URLs or formatted content |
| Phase count validation | Adds a confirmation step that may feel unnecessary for simple edits |
| Discovery not gated behind auth | Anonymous users can still trigger expensive AI calls, but rate-limited to 5/min |

**Overall philosophy**: Err on the side of safety. The cost of a security incident (data leak, prompt injection, cost attack) far outweighs the cost of slightly more friction for users. Guardrails can always be loosened once monitoring shows they're too aggressive.

---

## Deferred Items Summary

These items are parked for future consideration:

1. **1.2B/1.3 Auth gate for discovery** - Monitor anonymous usage; gate if abuse detected
2. **1.2C Token/cost tracking** - Add when AI usage volume warrants cost monitoring
3. **2.1B Off-topic pre-filter** - Add if domain constraints in prompts prove insufficient
4. **4.2C Periodic cleanup CRON** - Add when AI-discovered provider volume grows
5. **4.3A Soft-delete + versioning** - Consider if phase count validation (4.3B) proves insufficient
6. **5.1 Prompt eval framework** - Build when prompt iteration frequency increases
7. **5.2 Image content moderation** - Add if inappropriate image uploads become an issue
8. **5.3 Feedback cost optimization** - Optimize when feedback volume justifies the effort
