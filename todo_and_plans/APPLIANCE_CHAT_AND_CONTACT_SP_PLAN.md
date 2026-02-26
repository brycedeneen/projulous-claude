# Appliance Chat & Contact Service Provider Plan

**Date**: 2026-02-25
**Status**: Implementation Complete
**Contributors**: Technical Architect, Frontend Designer, Mobile Designer, Prompt Engineer

> **Key Design Decision (2026-02-25)**: PJ acts as a **concierge** to help users find repair professionals — NOT a diagnostic assistant. PJ does not provide DIY advice, troubleshooting steps, or attempt to diagnose root causes. The flow is: user describes problem -> PJ confirms understanding (1-2 exchanges max) -> generates problem summary -> finds repair pro.

---

## Overview

This plan covers four interconnected features:

1. **Appliance Details Chat** - Users chat with PJ directly on the appliance details screen (instead of being redirected to the home page)
2. **Contact Service Provider Flow** - After diagnosing a problem, users can contact an SP with the problem summary, appliance details, and chat history
3. **Reusable Chat Component** - Shared chat primitives across home, projects, and appliances
4. **Service Provider Preferred Contact Method** - SPs set their preferred contact method (email, text, phone)

---

## Table of Contents

- [Phase 1: Data Model & Shared DTO](#phase-1-data-model--shared-dto)
- [Phase 2: Backend Services](#phase-2-backend-services)
- [Phase 3: AI Prompts & Chat Flow](#phase-3-ai-prompts--chat-flow)
- [Phase 4: Reusable Chat Components (Web)](#phase-4-reusable-chat-components-web)
- [Phase 5: Appliance Chat UI (Web)](#phase-5-appliance-chat-ui-web)
- [Phase 6: Mobile Implementation](#phase-6-mobile-implementation)
- [Phase 7: Contact SP Flow (Full Stack)](#phase-7-contact-sp-flow-full-stack)
- [Phase 8: SP Preferred Contact Method](#phase-8-sp-preferred-contact-method)
- [Open Questions](#open-questions)

---

## Phase 1: Data Model & Shared DTO

### New Enum: `PreferredContactMethodENUM`

**File**: `projulous-shared-dto-node/shared/enums/preferredContactMethod.enum.ts`

```typescript
export enum PreferredContactMethodENUM {
  EMAIL = 'EMAIL',
  PHONE = 'PHONE',
  TEXT = 'TEXT',
}
```

### Enum Changes

**ConversationTypeENUM** - Add:
```
APPLIANCE_SUPPORT = 'APPLIANCE_SUPPORT'
```

**ConversationStatusENUM** - Add:
```
APPLIANCE_DIAGNOSING = 'APPLIANCE_DIAGNOSING'
APPLIANCE_SUMMARY_READY = 'APPLIANCE_SUMMARY_READY'
APPLIANCE_ROUTING_TO_SP = 'APPLIANCE_ROUTING_TO_SP'
```

### Entity Changes

| Entity | New Fields |
|--------|------------|
| `Conversation` | `customerApplianceId` (nullable UUID) |
| `ServiceProvider` | `preferredContactMethod` (nullable enum) |
| `QuoteRequest` | `customerApplianceId` (nullable UUID), `chatSummary` (nullable text) |

### DTO Changes

| DTO | New Fields |
|-----|------------|
| `ChatRequestDto` | `customerApplianceId` (optional) |
| `ChatResponseDto` | `contactReady` (optional bool), `problemSummary` (optional object) |
| `CreateQuoteRequestDTO` | `customerApplianceId`, `chatSummary`, `conversationId` (all optional) |
| `CreateServiceProviderDTO` | `preferredContactMethod` (optional) |
| `UpdateServiceProviderDTO` | `preferredContactMethod` (optional) |

### Migration

After entity changes:
1. Build & push `projulous-shared-dto-node`
2. `npm install projulous-shared-dto-node` in projulous-svc
3. `npm run migration:generate -- src/migrations/AddApplianceChatAndContactSP`
4. Review generated SQL
5. All new columns nullable = backward compatible

---

## Phase 2: Backend Services

### New API Endpoint

```
POST /v1/projulous-ai/appliances/:applianceId/conversation
```
- Creates a conversation with type `APPLIANCE_SUPPORT`, links `customerApplianceId`
- Fetches appliance with devices, place, service history, maintenance reminders
- Builds appliance context, sends to AI
- Returns ChatResponseDto with `conversationId`
- Auth: Required, rate limited (15 req/min)

### New Service: `ApplianceChatService`

**File**: `projulous-svc/src/projulousAI/services/applianceChat.service.ts`

Methods:
- `handleCreateApplianceConversation(user, applianceId, message)` - Creates conversation, builds context, gets first AI response
- `handleDiagnosticMessage(user, dto, conversation, language)` - Handles ongoing diagnostic chat
- `handleSummaryResponse(user, dto, conversation, language)` - Handles user review of problem summary
- `generateProblemSummary(conversation, applianceContext)` - AI-generated structured summary

### New Utility: `ApplianceContextBuilder`

**File**: `projulous-svc/src/projulousAI/utils/applianceContextBuilder.ts`

Builds a compact text block from `CustomerAppliance` entity data including:
- Name, type, brand, model, serial
- Age, warranty status (calculated)
- Recent service history (last 5)
- Upcoming maintenance (next 3)
- Location, energy rating

### Routing in `ChatService.handleChatMessage()`

```typescript
if (existingConversation?.conversationType === ConversationTypeENUM.APPLIANCE_SUPPORT) {
  if (status === APPLIANCE_DIAGNOSING) -> applianceChatService.handleDiagnosticMessage()
  if (status === APPLIANCE_SUMMARY_READY) -> applianceChatService.handleSummaryResponse()
}
```

### ConversationService Addition

```typescript
createApplianceConversation(user, applianceName, applianceId, language?)
```
Follows same pattern as existing `createProjectConversation()`.

### QuoteRequest Enhancement

- `createQuoteRequest()` accepts optional `conversationId`, `customerApplianceId`, `chatSummary`
- `QuoteRequestEventController` enhanced with email dispatch via `EmailService`

---

## Phase 3: AI Prompts & Chat Flow

### New Prompts (3 total)

#### 1. `applianceDiagnosticChat`

System prompt for diagnostic conversations. Key aspects:
- Full appliance context injection (brand, model, serial, warranty, service history)
- Diagnostic approach: ask focused questions, narrow down symptoms
- **Safety rules (CRITICAL)**: Never instruct on electrical panels, gas lines, refrigerant. Safe DIY limited to: filters, coils, breakers (exterior), drains, thermostats, leveling, lint traps
- Warranty awareness: recommend manufacturer/authorized service if warranty ACTIVE
- Scope boundaries: appliance/home topics only
- **Hidden metadata pattern**: Each response includes `<!--PJ_META:{"needsPro":false,"confidence":"low","suggestedOfferingType":null}-->` for backend to detect when professional help is needed

#### 2. `applianceDiagnosticIntent` (fallback/validation)

Classifies user messages into: `DESCRIBE_SYMPTOM`, `ASK_MAINTENANCE`, `ASK_GENERAL`, `READY_FOR_PRO`, `PROVIDE_INFO`, `OFF_TOPIC`. Used as a validation layer, not primary detection (hidden metadata is primary).

#### 3. `applianceProblemSummary`

Generates structured JSON for service providers:
```json
{
  "title": "GE Refrigerator - Compressor grinding noise",
  "description": "The homeowner reports...",
  "suggestedOfferingType": "APPLIANCE_REPAIR",
  "urgencyHint": "URGENT",
  "safetyNotes": null,
  "warrantyNote": "Warranty expired Jan 2025",
  "keySymptoms": ["Grinding noise from compressor", "Worse in afternoon", "Started 3 days ago"]
}
```
Always generated in English regardless of user language.

### Model Selection

All operations use **Gemini Flash** (fast, cheap, sufficient quality for Q&A diagnosis).

### Multi-Language

- Use existing `wrapWithLanguageInstruction()` for EN/ES/FR
- New chat messages in `chatMessages.ts` for appliance-specific UI text
- Problem summaries always in English

### Safety Guardrails (3 layers)

1. **Prompt-level**: Explicit safety rules, off-topic handling, anti-injection
2. **Output validation**: Regex patterns detecting dangerous instructions (gas, electrical, refrigerant) -> replace with safe fallback
3. **UI disclaimer**: Persistent text below chat widget

### "Ready to Contact SP" Detection (3 triggers)

1. **User explicit**: "I need a repair person" -> hidden metadata `needsPro: true`
2. **PJ conclusion**: Safety concern or complexity -> metadata `needsPro: true`
3. **Turn-count heuristic**: After 8+ turns, proactively suggest finding SP

---

## Phase 4: Reusable Chat Components (Web)

### Current State (3 implementations)

| Location | Component | Style | Features |
|----------|-----------|-------|----------|
| Home | `PromptInput` (~720 lines) | `ChatMessage` bubbles | Full find-SP flow, multi-service |
| Projects | `ProjectPlannerChat` (~245 lines) | Custom inline | Optimistic updates, thinking indicator, quick actions |
| Conversations | `ConversationComponent` (~192 lines) | Timeline | Form submit, no optimistic updates |

### Proposed Shared Components

**Directory**: `app/shared/components/chat/` (partially exists)

| Component | Status | Purpose |
|-----------|--------|---------|
| `ChatMessage.tsx` | Exists | Message bubble (user/system) |
| `ProviderResults.tsx` | Exists | Provider search results |
| `ProviderCard.tsx` | Exists | Individual provider card |
| `SkeletonProviderResults.tsx` | Exists | Loading state |
| `DiscoveryErrorFallback.tsx` | Exists | Error fallback |
| `ThinkingIndicator.tsx` | **NEW** | Cycling "thinking/imagining/considering" animation (extract from ProjectPlannerChat) |
| `ChatInput.tsx` | **NEW** | Unified textarea + send button, Enter-to-send |
| `QuickActions.tsx` | **NEW** | Contextual suggestion chips |
| `ChatEmptyState.tsx` | **NEW** | Configurable empty state with icon + text |

### Shared Hook: `useChatConversation`

```typescript
interface UseChatConversationOptions {
  conversationId?: string;
  createConversationFn?: (message: string) => Promise<{ conversationId: string; message: string }>;
  onConversationCreated?: (conversationId: string) => void;
}

interface UseChatConversationResult {
  messages: ConversationMessageResult[];
  isLoading: boolean;
  isSending: boolean;
  sendMessage: (message: string) => Promise<void>;
  conversationId: string | undefined;
}
```

### Visual Consistency Rules

- User bubbles: `bg-blue-500 text-white rounded-2xl rounded-tr-sm` (right-aligned)
- AI bubbles: `bg-gray-700 text-gray-100 rounded-2xl rounded-tl-sm` (left-aligned)
- Enter sends, Shift+Enter for newline
- Thinking indicator: cycling words with bouncing dots

### Migration Path

| Priority | Location | Action |
|----------|----------|--------|
| P0 | Appliance detail | New widget using shared components |
| P1 | Project detail | Refactor `ProjectPlannerChat` to use shared components |
| P2 | Home page | Refactor `PromptInput` to use shared components (most complex) |
| N/A | Conversation component | Keep separate (human-to-human messaging, different UX pattern) |

---

## Phase 5: Appliance Chat UI (Web)

### Layout

Replace current "Need Service?" section (textarea + redirect) with an in-page chat widget:

```
+------------------------------------------------------------+
| Chat with PJ about this appliance                          |
| (gradient border: blue-to-indigo)                          |
|                                                            |
| [Wrench icon] Ask PJ about your [Appliance Name]          |
|               AI assistant for diagnostics & service       |
|                                                            |
| +--------------------------------------------------------+|
| | Messages area (min-h: 200px, max-h: 400px, scrollable) ||
| | [Empty state / Messages / ThinkingIndicator]            ||
| +--------------------------------------------------------+|
|                                                            |
| Quick actions: [Diagnose an issue] [Maintenance] [Find SP] |
|                                                            |
| [textarea: "Describe your issue..."]           [Send]      |
+------------------------------------------------------------+
```

### Specifications

- Container: `rounded-xl border border-zinc-200 dark:border-white/10`, gradient bg
- Messages: min-h 200px, max-h 400px, overflow-y-auto, auto-scroll
- Quick action chips: contextual suggestions, hidden after first message
- Input: Shared `ChatInput` with Enter-to-send

### States

| State | Display |
|-------|---------|
| Empty | Icon + helper text + quick action chips |
| Active | Message history + input |
| Thinking | ThinkingIndicator below last message |
| Ready to contact | "Contact Service Provider" button appears |
| Error | Inline red error banner |

### Data Access

New method in `ConversationDA`:
```typescript
static async createApplianceConversation(applianceId: string, message: string)
```

### Accessibility

- Messages area: `role="log"` `aria-live="polite"`
- Thinking indicator: `role="status"` `aria-label="PJ is thinking"`
- Input: `aria-label="Type your message to PJ"`
- Quick actions: `role="group"` `aria-label="Suggested questions"`
- All touch targets >= 44px

---

## Phase 6: Mobile Implementation

### Approach: FAB + Bottom Sheet

Instead of embedding chat inline (scroll-within-scroll problems), use:
1. **Floating Action Button (FAB)** in thumb zone: "Chat with PJ"
2. **Bottom sheet** (85% screen height) with the chat interface

```
Appliance Detail Screen                   Bottom Sheet (when open)
+---------------------------+             +---------------------------+
| [existing scroll content] |             | --- (drag handle) ---     |
| [no more "Need Service?"] |             | Chat about Kitchen Fridge |
|                           |             +---------------------------+
|                   +-----+ |             | [Appliance Context Card]  |
|                   |Chat | |  ->tap->    | [Messages]                |
|                   | PJ  | |             | [ChatInput]               |
|                   +-----+ |             +---------------------------+
+---------------------------+
```

### Why Bottom Sheet (Not Inline)

- Avoids scroll-within-scroll conflict
- Independent keyboard handling
- User can dismiss to reference appliance details
- Reusable pattern for future screens

### Reusable Chat Architecture (Mobile)

Extract shared composite component from `pj.tsx`:

```
PJChatView (NEW composite)
  +-- ChatHeader (optional, configurable)
  +-- KeyboardAvoidingView
        +-- ChatMessageList (existing)
        |     +-- ChatBubble, LoadingIndicator, etc.
        |     +-- ApplianceContextCard (NEW)
        |     +-- ContactSPCard (NEW)
        +-- ChatInput (existing)
```

### New Mobile Components

| Component | Purpose |
|-----------|---------|
| `pj-chat-view.tsx` | Reusable composite (extracted from pj.tsx) |
| `chat-bottom-sheet.tsx` | Animated bottom sheet container |
| `appliance-context-card.tsx` | Compact appliance summary at top of chat |
| `contact-sp-card.tsx` | Post-diagnosis CTA card |
| `project-created-card.tsx` | Confirmation after project creation |

### `usePJChat` Hook Changes

Add new options:
```typescript
applianceContext?: ApplianceContext;  // Appliance data for context injection
mode?: 'full' | 'embedded';         // Suppress drawer features in embedded mode
```

### Interactions

| Action | Behavior |
|--------|----------|
| Tap FAB | Bottom sheet slides up (spring, 300ms), light haptic (iOS) |
| Drag handle | Interactive dismiss, snaps closed at 40% threshold |
| Tap overlay | Dismiss with fade |
| Send message | Light haptic, auto-scroll |
| Keyboard | KeyboardAvoidingView adjusts independently |

### Platform Differences

| Aspect | iOS | Android |
|--------|-----|---------|
| Sheet animation | Spring with damping | Timing with material easing |
| Keyboard | `behavior="padding"` | `behavior="height"` |
| Back gesture | Edge swipe = navigation | Back button = dismiss sheet |
| Haptics | Full via expo-haptics | `process.env.EXPO_OS` check |

---

## Phase 7: Contact SP Flow (Full Stack)

### User Journey

```
1. User chats about appliance issue on detail screen
2. PJ diagnoses problem (multi-turn)
3. PJ determines professional help needed -> needsPro: true
4. UI shows "Contact Service Provider" card
5. User confirms, selects/searches for SP
6. System creates QuoteRequest with full context
7. Email sent to SP with appliance details + problem summary
8. Customer gets confirmation notification
```

### Contact SP Modal (Web)

```
+------------------------------------------------------------+
| Contact Service Providers                            [X]    |
+------------------------------------------------------------+
| Problem Summary (editable)                                  |
| "Grinding noise from compressor area..."              [Edit]|
|                                                             |
| Appliance Information (read-only)                           |
| Name: Kitchen Refrigerator | Brand: Samsung | Model: RF28  |
|                                                             |
| Selected Providers                                          |
| [v] ABC Appliance Repair - Contact: Email                   |
| [v] XYZ HVAC - Contact: Phone                               |
|                                                             |
| Additional Notes (optional textarea)                         |
| Preferred Contact Time: [Morning] [Afternoon] [Evening]     |
|                                                             |
|            [Cancel]              [Send Request]              |
+------------------------------------------------------------+
```

### Email Template for SP

```
Subject: Service Request: {applianceType} - {customerName}

Hello {spName},

APPLIANCE INFORMATION
- Type: {applianceType}
- Brand: {manufacturer}
- Model: {modelNumber}
- Serial: {serialNumber}
- Warranty: {warrantyStatus}

PROBLEM DESCRIPTION
{AI-generated problem summary}

CUSTOMER INFORMATION
- Name: {customerName}
- Preferred Contact: {contactPreference}

-- The Projulous Team
```

### Backend: QuoteRequestEventController Enhancement

- On `QUOTE_REQUEST_CREATE`:
  - Fetch SP email/phone/preferredContactMethod
  - Build email with problem summary + appliance details
  - Send via `EmailService` (AWS SES)
  - Send confirmation notification to customer
- If SP prefers TEXT (Phase 1): send email + note "This SP prefers text at {phone}"
- SMS integration deferred to Phase 2 (requires Twilio/SNS)

---

## Phase 8: SP Preferred Contact Method

### Backend

- `ServiceProviderService.updateServiceProvider()` already handles arbitrary field updates
- No new endpoint needed, existing `PUT /v1/service-providers/:id` handles it

### Web UI

- Add preference selector to SP management/onboarding settings
- Options: Email (default), Phone, Text

### Mobile UI

- Add preference selector to SP profile settings

---

## Open Questions

1. **Should PJ proactively suggest contacting an SP, or wait for user?**
   - Recommendation: PJ suggests after 3-4 diagnostic exchanges, user controls timing

2. **Should user select from existing project SPs or always search?**
   - Recommendation: If appliance has `installedByServiceProvider`, offer that SP first. Otherwise search.

3. **Should chat persist when user navigates away and returns?**
   - Recommendation: Yes. Look up by `customerApplianceId` + `APPLIANCE_SUPPORT` + non-terminal status on screen mount.

4. **Multi-language problem summaries?**
   - Recommendation: Generate in English only (SP may not speak user's language). Revisit when SP language preference is available.

5. **SMS for Phase 1?**
   - Recommendation: No. Defer to Phase 2. For now, if SP prefers text, send email with note about their text preference.

---

## Implementation Order

| Phase | Description | Dependencies | Effort |
|-------|-------------|--------------|--------|
| 1 | Data Model & Shared DTO | None | Small |
| 2 | Backend Services | Phase 1 | Medium |
| 3 | AI Prompts & Chat Flow | Phase 2 | Medium |
| 4 | Reusable Chat Components (Web) | None | Medium |
| 5 | Appliance Chat UI (Web) | Phases 2-4 | Medium |
| 6 | Mobile Implementation | Phases 2-3 | Medium-Large |
| 7 | Contact SP Flow | Phases 2, 5-6 | Medium |
| 8 | SP Preferred Contact | Phase 1 | Small |

**Phases 1 + 4 can run in parallel** (no dependencies between them).
**Phases 2 + 3 are sequential** (prompts need the service layer).
**Phases 5, 6, 8 can run in parallel** once their dependencies are met.

---

## Files Summary

### New Files

| File | Purpose |
|------|---------|
| `shared-dto: shared/enums/preferredContactMethod.enum.ts` | New enum |
| `svc: projulousAI/utils/applianceContextBuilder.ts` | Appliance context for prompts |
| `svc: projulousAI/services/applianceChat.service.ts` | Appliance diagnostic chat flow |
| `svc: projulousAI/schemas/applianceChatSchemas.ts` | Zod schemas for intent/summary |
| `web: shared/components/chat/ThinkingIndicator.tsx` | Shared thinking animation |
| `web: shared/components/chat/ChatInput.tsx` | Shared chat input |
| `web: shared/components/chat/QuickActions.tsx` | Shared suggestion chips |
| `web: shared/components/chat/ChatEmptyState.tsx` | Shared empty state |
| `web: routes/customers/appliances/applianceChat.component.tsx` | Appliance chat widget |
| `web: routes/customers/appliances/contactProviderModal.component.tsx` | Contact SP modal |
| `mobile: components/chat/pj-chat-view.tsx` | Reusable composite chat view |
| `mobile: components/chat/chat-bottom-sheet.tsx` | Bottom sheet container |
| `mobile: components/chat/appliance-context-card.tsx` | Appliance summary card |
| `mobile: components/chat/contact-sp-card.tsx` | Post-diagnosis CTA |
| `mobile: components/chat/project-created-card.tsx` | Project creation confirmation |

### Modified Files

| File | Changes |
|------|---------|
| `shared-dto: conversation/conversation.entity.ts` | Add `customerApplianceId` |
| `shared-dto: shared/enums/conversationType.enum.ts` | Add `APPLIANCE_SUPPORT` |
| `shared-dto: shared/enums/conversationStatus.enum.ts` | Add 3 statuses |
| `shared-dto: serviceProvider/serviceProvider.entity.ts` | Add `preferredContactMethod` |
| `shared-dto: quoteRequest/quoteRequest.entity.ts` | Add fields |
| `shared-dto: conversation/chat.dto.ts` | Add fields |
| `svc: projulousAI/prompts/prompts.config.ts` | Add 3 prompts |
| `svc: projulousAI/prompts/prompt.service.ts` | Add 3 wrapper methods |
| `svc: projulousAI/messages/chatMessages.ts` | Add appliance messages EN/ES/FR |
| `svc: projulousAI/services/chat.service.ts` | Add APPLIANCE_SUPPORT routing |
| `svc: projulousAI/controllers/chat.controller.ts` | Add new endpoint |
| `svc: quoteRequest/services/quoteRequest.service.ts` | Accept appliance context |
| `svc: quoteRequest/eventControllers/quoteRequest.eventController.ts` | Email dispatch |
| `web: routes/customers/appliances/appliance.route.tsx` | Replace "Need Service?" with chat |
| `web: dataAccess/conversation/conversation.da.tsx` | Add createApplianceConversation |
| `mobile: app/(tabs)/pj.tsx` | Refactor to use PJChatView |
| `mobile: app/appliance/[applianceId].tsx` | Remove "Need Service?", add FAB + sheet |
| `mobile: hooks/use-pj-chat.ts` | Add applianceContext, mode options |
| `mobile: components/chat/chat-message-list.tsx` | Add new item types |
