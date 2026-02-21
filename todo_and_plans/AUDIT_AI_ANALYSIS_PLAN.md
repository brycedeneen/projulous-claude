# Audit Log AI Analysis Plan

**Feature**: Select audit log records and send them to Gemini for summarization, pattern detection, and troubleshooting.

---

## Overview

Add a "PJ Analyze" mode to the Audit Logs admin page. Users can select 1-N audit log rows, optionally provide context (e.g. "User reported they couldn't save their project"), and get an AI-generated analysis including: summary of what happened, timeline reconstruction, anomaly detection, and troubleshooting suggestions.

---

## Phase 1: Backend

### 1.1 New AIOperationENUM Value

**File**: `projulous-svc/src/projulousAI/constants/aiInteractionConstants.ts`

Add to `AIOperationENUM`:
```typescript
ANALYZE_AUDIT_LOGS = 'ANALYZE_AUDIT_LOGS',
```

### 1.2 New Prompt

**File**: `projulous-svc/src/projulousAI/prompts/prompts.config.ts`

Add a new prompt key `AUDIT_LOG_ANALYSIS` to the registry:

```
You are PJ, an expert system administrator and auditor for the Projulous platform.
You are analyzing audit log entries to help administrators understand system activity.

Given the following audit log records (in JSON format), provide:

1. **Summary**: A concise overview of what happened (who did what, to which entities, and when).
2. **Timeline**: A chronological reconstruction of events, noting any causal relationships.
3. **Patterns**: Any notable patterns (e.g., rapid successive deletes, same user modifying many records, unusual timing).
4. **Anomalies**: Flag anything that looks unusual or potentially problematic (e.g., deletes without prior updates, actions outside business hours, orphaned operations).
5. **Troubleshooting**: If the admin provided additional context, correlate the audit data with their description and suggest root causes or next steps.

Keep the response clear and actionable. Use entity names and user names (not UUIDs) where possible.
If no user context is provided, skip the Troubleshooting section.
```

**File**: `projulous-svc/src/projulousAI/prompts/prompt.service.ts`

Add method:
```typescript
getAuditLogAnalysisPrompt(): string {
  return this.getPrompt(PromptName.AUDIT_LOG_ANALYSIS);
}
```

### 1.3 New AI Service Method

**File**: `projulous-svc/src/projulousAI/services/auditAnalysisAI.service.ts` (new file)

```typescript
@Injectable()
export class AuditAnalysisAIService {
  private geminiAIClient: GoogleGenAI;

  constructor(
    private readonly promptService: PromptService,
    private readonly aiLogger: AIInteractionLoggerService,
  ) {
    this.geminiAIClient = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  }

  async analyzeAuditLogs(
    auditLogs: AuditLog[],
    userContext?: string,
    userId?: string,
  ): Promise<AuditAnalysisResult> {
    // 1. Format audit logs into a readable JSON payload
    // 2. Build system prompt via PromptService
    // 3. Build user message: formatted logs + optional user context
    // 4. Call Gemini via withGeminiLogging
    // 5. Parse markdown response
    // 6. Return structured result
  }
}
```

**Input formatting**: Strip large JSONB fields (newValues) down to key summaries to stay within token limits. Keep changedFields, entityName, entityId, action, eventType, user info, timestamps.

**Response type**:
```typescript
export interface AuditAnalysisResult {
  summary: string;
  timeline: string;
  patterns: string;
  anomalies: string;
  troubleshooting?: string; // Only if userContext was provided
}
```

Use `responseMimeType: 'application/json'` with a Zod schema for structured output.

### 1.4 New GraphQL Mutation

**File**: `projulous-svc/src/audit/audit.resolver.ts`

Add a new mutation (not query, since it triggers an AI call with side effects):

```graphql
mutation AnalyzeAuditLogs($input: AnalyzeAuditLogsInput!) {
  analyzeAuditLogs(input: $input) {
    summary
    timeline
    patterns
    anomalies
    troubleshooting
  }
}
```

**Input type**:
```typescript
@InputType()
class AnalyzeAuditLogsInput {
  @Field(() => [String])
  auditLogIds: string[]; // 1-50 IDs

  @Field({ nullable: true })
  userContext?: string; // Optional admin-provided context (max 1000 chars)
}
```

**Guards**: Same as existing audit queries - `SUPER_ADMIN_SUPER_ADMIN` permission.

**Flow**:
1. Validate: 1-50 auditLogIds, userContext max 1000 chars
2. Fetch full audit log records by IDs (with user relation)
3. Call `AuditAnalysisAIService.analyzeAuditLogs()`
4. Return result

### 1.5 Module Registration

**File**: `projulous-svc/src/audit/audit.module.ts`

- Import `AuditAnalysisAIService`
- Add to providers
- Import `ProjulousAIModule` for `PromptService` and `AIInteractionLoggerService`

### 1.6 Token Budget Consideration

Audit logs with `newValues` can be large. To stay within Gemini's context window:

- Limit to **50 audit log records** per analysis request
- Truncate `newValues` to top-level keys only (not nested values) if the record exceeds 500 chars
- Strip `metadata` unless it contains meaningful info
- Include `changedFields` in full (these are compact)
- Estimated max payload: ~50 records x ~300 chars = ~15K chars (well within limits)

---

## Phase 2: Frontend

### 2.1 Selection Mode

**File**: `projulous-web/app/routes/admin/audit/auditLogAdmin.route.tsx`

Add state:
```typescript
const [selectMode, setSelectMode] = useState(false);
const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
```

**UI changes**:
- Add "PJ Analyze" toggle button in the header area (next to title or above filters)
- When `selectMode` is true:
  - Show checkboxes in the first column of each row
  - Show a floating action bar at the bottom with: selected count, "Analyze" button, "Cancel" button
  - "Select All on Page" / "Deselect All" convenience buttons
- Clicking a row in select mode toggles selection (instead of expanding details)

### 2.2 Context Input

When user clicks "Analyze" with selected records:
- Show a modal/drawer with:
  - Count of selected records
  - Optional textarea: "Provide context (optional)" with placeholder "e.g., User reported they couldn't save their project around 3pm"
  - "Analyze" (primary) and "Cancel" buttons
  - 1000 char limit indicator on textarea

### 2.3 Analysis Result Display

After the API returns:
- Show results in a modal or slide-over panel with sections:
  - **Summary** - rendered as markdown
  - **Timeline** - rendered as markdown
  - **Patterns** - rendered as markdown
  - **Anomalies** - rendered as markdown (highlight with amber/warning styling)
  - **Troubleshooting** - rendered as markdown (only shown if userContext was provided)
- Each section is collapsible
- "Copy to Clipboard" button for the full analysis
- Loading state with spinner while waiting for AI response

### 2.4 Data Access

**File**: `projulous-web/app/dataAccess/admin/auditLog.da.tsx`

Add method:
```typescript
static async analyzeAuditLogs(
  auditLogIds: string[],
  userContext?: string,
): Promise<AuditAnalysisResult> {
  const data = await graphqlQueryData(
    `mutation AnalyzeAuditLogs($input: AnalyzeAuditLogsInput!) {
      analyzeAuditLogs(input: $input) {
        summary
        timeline
        patterns
        anomalies
        troubleshooting
      }
    }`,
    { input: { auditLogIds, userContext: userContext || undefined } },
  );
  return data?.data?.analyzeAuditLogs;
}
```

---

## Phase 3: Polish & Safety

### 3.1 Rate Limiting
- Add rate limiting to the mutation: max 10 analysis requests per minute per user
- Prevents abuse of the AI endpoint

### 3.2 Input Sanitization
- Strip any PII from userContext before sending to Gemini (or at minimum, warn the admin)
- Sanitize audit log data: remove `hashedPassword`, `refreshTokenHash`, `verificationCode` fields from newValues before sending

### 3.3 Error Handling
- If Gemini returns an error or times out, show a user-friendly message
- If too many records selected (>50), show validation error before making the call
- If audit log fetch returns fewer records than requested IDs (some deleted), proceed with available records

### 3.4 Cost Tracking
- All calls logged via `withGeminiLogging` with operation `ANALYZE_AUDIT_LOGS`
- Token usage tracked in AIInteractionLog for cost monitoring

---

## File Change Summary

| File | Change |
|------|--------|
| `projulous-svc/src/projulousAI/constants/aiInteractionConstants.ts` | Add `ANALYZE_AUDIT_LOGS` to `AIOperationENUM` |
| `projulous-svc/src/projulousAI/prompts/prompts.config.ts` | Add `AUDIT_LOG_ANALYSIS` prompt |
| `projulous-svc/src/projulousAI/prompts/prompt.service.ts` | Add `getAuditLogAnalysisPrompt()` |
| `projulous-svc/src/projulousAI/services/auditAnalysisAI.service.ts` | **New file** - AI service for audit analysis |
| `projulous-svc/src/audit/audit.resolver.ts` | Add `AnalyzeAuditLogsInput` + mutation |
| `projulous-svc/src/audit/audit.service.ts` | Add `getAuditLogsByIds()` helper |
| `projulous-svc/src/audit/audit.module.ts` | Register new service, import AI module |
| `projulous-web/app/dataAccess/admin/auditLog.da.tsx` | Add `analyzeAuditLogs()` method + result type |
| `projulous-web/app/routes/admin/audit/auditLogAdmin.route.tsx` | Selection mode, context modal, results panel |

---

## Estimated Effort

- **Phase 1 (Backend)**: ~2-3 hours
- **Phase 2 (Frontend)**: ~2-3 hours
- **Phase 3 (Polish)**: ~1 hour
- **Total**: ~5-7 hours

---

## Dependencies

- Gemini API key must be configured in environment
- No shared-dto changes needed (all new types are local to svc resolver)
- No database migrations needed
- No new permissions needed (reuses `SUPER_ADMIN_SUPER_ADMIN`)
