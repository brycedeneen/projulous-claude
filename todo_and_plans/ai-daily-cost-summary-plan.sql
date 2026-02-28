-- ============================================================
-- AI Daily Cost Summary Table
-- ============================================================
-- Purpose: Pre-aggregated daily cost summaries to avoid
--          expensive on-the-fly rollups over the growing
--          AIInteractionLogs table.
--
-- Strategy:
--   - One row per (date, provider, model, operation) combo
--   - CRON job runs nightly to summarize previous day
--   - Backfill script populates historical days
--   - getCostSummary queries this table instead of raw logs
--
-- Benefits:
--   - Dashboard queries hit ~30 rows/day instead of 400+
--   - Constant query time regardless of log volume
--   - Easy to add weekly/monthly rollups later
-- ============================================================

-- ============================================================
-- MIGRATION: Create AIDailyCostSummaries table
-- ============================================================
-- NOTE: This should be implemented as a TypeORM migration.
-- The SQL below is the reference for the migration.

CREATE TABLE IF NOT EXISTS "AIDailyCostSummaries" (
  "aiDailyCostSummaryId" uuid NOT NULL DEFAULT uuid_generate_v4(),

  -- Dimensions (what we group by)
  "summaryDate"       DATE         NOT NULL,  -- The day being summarized
  "provider"          VARCHAR(64)  NOT NULL,
  "model"             VARCHAR(128) NOT NULL,
  "operation"         VARCHAR(128) NOT NULL,

  -- Metrics
  "requestCount"      INTEGER      NOT NULL DEFAULT 0,
  "successCount"      INTEGER      NOT NULL DEFAULT 0,
  "errorCount"        INTEGER      NOT NULL DEFAULT 0,

  -- Token usage
  "totalPromptTokens"      BIGINT  NOT NULL DEFAULT 0,
  "totalCompletionTokens"  BIGINT  NOT NULL DEFAULT 0,
  "totalCachedInputTokens" BIGINT  NOT NULL DEFAULT 0,
  "totalSearchGroundingRequests" INTEGER NOT NULL DEFAULT 0,

  -- Cost
  "totalCostUsd"      NUMERIC(12,6) NOT NULL DEFAULT 0,
  "avgCostPerRequest"  NUMERIC(10,8) NOT NULL DEFAULT 0,

  -- Performance
  "avgLatencyMs"      INTEGER      NOT NULL DEFAULT 0,
  "p95LatencyMs"      INTEGER,     -- optional, nice to have

  -- Standard fields
  "createdDate"       TIMESTAMP    NOT NULL DEFAULT now(),
  "updatedDate"       TIMESTAMP    NOT NULL DEFAULT now(),

  CONSTRAINT "PK_ai_daily_cost_summary" PRIMARY KEY ("aiDailyCostSummaryId"),

  -- One row per (date, provider, model, operation) — upsert target
  CONSTRAINT "UQ_ai_daily_cost_summary_key"
    UNIQUE ("summaryDate", "provider", "model", "operation")
);

-- Index for dashboard queries (date range + optional filters)
CREATE INDEX IF NOT EXISTS "IDX_ai_daily_cost_summary_date"
  ON "AIDailyCostSummaries" ("summaryDate" DESC);

CREATE INDEX IF NOT EXISTS "IDX_ai_daily_cost_summary_lookup"
  ON "AIDailyCostSummaries" ("summaryDate" DESC, "provider", "model");


-- ============================================================
-- BACKFILL: Populate from existing AIInteractionLogs
-- ============================================================
-- Run once after creating the table to fill in historical data.

INSERT INTO "AIDailyCostSummaries" (
  "summaryDate", "provider", "model", "operation",
  "requestCount", "successCount", "errorCount",
  "totalPromptTokens", "totalCompletionTokens",
  "totalCachedInputTokens", "totalSearchGroundingRequests",
  "totalCostUsd", "avgCostPerRequest", "avgLatencyMs"
)
SELECT
  DATE("createdDate") AS "summaryDate",
  provider,
  model,
  operation,
  COUNT(*)::int AS "requestCount",
  COUNT(*) FILTER (WHERE success = true)::int AS "successCount",
  COUNT(*) FILTER (WHERE success = false)::int AS "errorCount",
  COALESCE(SUM("promptTokens"), 0) AS "totalPromptTokens",
  COALESCE(SUM("completionTokens"), 0) AS "totalCompletionTokens",
  COALESCE(SUM("cachedInputTokens"), 0) AS "totalCachedInputTokens",
  COALESCE(SUM("searchGroundingRequests"), 0)::int AS "totalSearchGroundingRequests",
  COALESCE(SUM("estimatedCostUsd"), 0) AS "totalCostUsd",
  CASE
    WHEN COUNT(*) > 0 THEN COALESCE(SUM("estimatedCostUsd"), 0) / COUNT(*)
    ELSE 0
  END AS "avgCostPerRequest",
  COALESCE(AVG("latencyMs"), 0)::int AS "avgLatencyMs"
FROM "AIInteractionLogs"
GROUP BY DATE("createdDate"), provider, model, operation
ON CONFLICT ("summaryDate", "provider", "model", "operation")
DO UPDATE SET
  "requestCount"      = EXCLUDED."requestCount",
  "successCount"      = EXCLUDED."successCount",
  "errorCount"        = EXCLUDED."errorCount",
  "totalPromptTokens" = EXCLUDED."totalPromptTokens",
  "totalCompletionTokens" = EXCLUDED."totalCompletionTokens",
  "totalCachedInputTokens" = EXCLUDED."totalCachedInputTokens",
  "totalSearchGroundingRequests" = EXCLUDED."totalSearchGroundingRequests",
  "totalCostUsd"      = EXCLUDED."totalCostUsd",
  "avgCostPerRequest"  = EXCLUDED."avgCostPerRequest",
  "avgLatencyMs"      = EXCLUDED."avgLatencyMs",
  "updatedDate"       = now();


-- ============================================================
-- NIGHTLY CRON: Summarize previous day
-- ============================================================
-- This is the query the NestJS CRON job should run daily.
-- Schedule: Every day at 00:15 UTC (after midnight, gives 15min buffer)
--
-- The CRON job upserts so it's safe to re-run.

-- @Cron('15 0 * * *')  -- 00:15 UTC daily
-- async summarizePreviousDay(): Promise<void>

INSERT INTO "AIDailyCostSummaries" (
  "summaryDate", "provider", "model", "operation",
  "requestCount", "successCount", "errorCount",
  "totalPromptTokens", "totalCompletionTokens",
  "totalCachedInputTokens", "totalSearchGroundingRequests",
  "totalCostUsd", "avgCostPerRequest", "avgLatencyMs"
)
SELECT
  DATE("createdDate") AS "summaryDate",
  provider,
  model,
  operation,
  COUNT(*)::int,
  COUNT(*) FILTER (WHERE success = true)::int,
  COUNT(*) FILTER (WHERE success = false)::int,
  COALESCE(SUM("promptTokens"), 0),
  COALESCE(SUM("completionTokens"), 0),
  COALESCE(SUM("cachedInputTokens"), 0),
  COALESCE(SUM("searchGroundingRequests"), 0)::int,
  COALESCE(SUM("estimatedCostUsd"), 0),
  CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM("estimatedCostUsd"), 0) / COUNT(*) ELSE 0 END,
  COALESCE(AVG("latencyMs"), 0)::int
FROM "AIInteractionLogs"
WHERE DATE("createdDate") = CURRENT_DATE - INTERVAL '1 day'
GROUP BY DATE("createdDate"), provider, model, operation
ON CONFLICT ("summaryDate", "provider", "model", "operation")
DO UPDATE SET
  "requestCount"      = EXCLUDED."requestCount",
  "successCount"      = EXCLUDED."successCount",
  "errorCount"        = EXCLUDED."errorCount",
  "totalPromptTokens" = EXCLUDED."totalPromptTokens",
  "totalCompletionTokens" = EXCLUDED."totalCompletionTokens",
  "totalCachedInputTokens" = EXCLUDED."totalCachedInputTokens",
  "totalSearchGroundingRequests" = EXCLUDED."totalSearchGroundingRequests",
  "totalCostUsd"      = EXCLUDED."totalCostUsd",
  "avgCostPerRequest"  = EXCLUDED."avgCostPerRequest",
  "avgLatencyMs"      = EXCLUDED."avgLatencyMs",
  "updatedDate"       = now();


-- ============================================================
-- SAMPLE DASHBOARD QUERIES (replace getCostSummary)
-- ============================================================

-- Total cost by day (last 30 days)
SELECT
  "summaryDate",
  SUM("requestCount") AS requests,
  ROUND(SUM("totalCostUsd")::numeric, 4) AS cost_usd
FROM "AIDailyCostSummaries"
WHERE "summaryDate" >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY "summaryDate"
ORDER BY "summaryDate" DESC;

-- Cost by model (last 30 days)
SELECT
  model,
  SUM("requestCount") AS requests,
  SUM("totalPromptTokens") AS input_tokens,
  SUM("totalCompletionTokens") AS output_tokens,
  ROUND(SUM("totalCostUsd")::numeric, 4) AS cost_usd
FROM "AIDailyCostSummaries"
WHERE "summaryDate" >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY model
ORDER BY cost_usd DESC;

-- Cost by operation (last 7 days)
SELECT
  operation,
  SUM("requestCount") AS requests,
  ROUND(SUM("totalCostUsd")::numeric, 4) AS cost_usd,
  ROUND(AVG("avgCostPerRequest")::numeric, 6) AS avg_per_call
FROM "AIDailyCostSummaries"
WHERE "summaryDate" >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY operation
ORDER BY cost_usd DESC;

-- Weekly rollup
SELECT
  DATE_TRUNC('week', "summaryDate")::date AS week_start,
  SUM("requestCount") AS requests,
  ROUND(SUM("totalCostUsd")::numeric, 4) AS cost_usd
FROM "AIDailyCostSummaries"
GROUP BY DATE_TRUNC('week', "summaryDate")
ORDER BY week_start DESC;
