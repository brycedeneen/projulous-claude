# Hybrid Tool Layer — Phase 5: MCP Adapter & Observability (Deferred)

**Status:** DEFERRED (Post-Launch)
**Prerequisites:** Phases 1-4 complete and shipped

---

## Scope

Expose the shared tool registry tools via the existing MCP server, and migrate current MCP project tools to use the shared registry.

## Tasks

### 5.1 Create McpSharedToolAdapter
- Create adapter that exposes shared ToolRegistry tools via `@rekog/mcp-nest`
- Map `mcpName` (kebab-case) to MCP tool names
- Reuse the same `execute()` functions and Zod schemas

### 5.2 Migrate Existing MCP Project Tools to Shared Registry
- Current MCP tools in `src/mcp/tools/project.tools.ts` (5 tools: list-customer-projects, get-customer-project, list-project-service-providers, create-customer-project, update-customer-project)
- Gradually delegate to shared registry definitions instead of duplicating service calls
- Maintain backward compatibility for existing MCP clients

### 5.3 Add Permission Checks to Existing MCP Tools
- Pre-existing gap: MCP tools don't check `requiredPermissions`
- Apply the same ToolRegistry permission check pattern to MCP-exposed tools

### 5.4 Extended Observability Dashboards
- Tool call metrics (success/failure rates, latency P50/P95)
- Tool selection accuracy tracking
- Per-tool usage frequency
- Leverage existing AIInteractionLog data (already being logged by GeminiAgentService)
