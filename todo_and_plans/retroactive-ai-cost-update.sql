-- ============================================================
-- Retroactive AI Cost Update Script
-- ============================================================
-- Purpose: Backfill estimatedCostUsd for all AIInteractionLogs
--          that have token data but no cost calculated.
--
-- Run AFTER: AIModelPricings has been seeded with pricing data.
-- Safe to re-run: Only updates rows where estimatedCostUsd IS NULL.
-- ============================================================

-- Step 0: Fix missing cachedInputTokenPricePerMillion (was null in seed)
UPDATE "AIModelPricings"
SET "cachedInputTokenPricePerMillion" = 0.050000
WHERE provider = 'GEMINI' AND model = 'gemini-3-flash-preview'
  AND "cachedInputTokenPricePerMillion" IS NULL;

UPDATE "AIModelPricings"
SET "cachedInputTokenPricePerMillion" = 0.200000
WHERE provider = 'GEMINI' AND model = 'gemini-3.1-pro-preview'
  AND "cachedInputTokenPricePerMillion" IS NULL;

-- ============================================================
-- Step 1: Preview — see what will be updated (DRY RUN)
-- ============================================================
SELECT
  l.provider,
  l.model,
  COUNT(*) AS records_to_update,
  SUM(l."promptTokens") AS total_input_tokens,
  SUM(l."completionTokens") AS total_output_tokens,
  -- Estimated total cost for this model
  SUM(
    COALESCE(
      -- Input cost: (promptTokens - cachedInputTokens) at input rate
      (GREATEST(COALESCE(l."promptTokens", 0) - COALESCE(l."cachedInputTokens", 0), 0)::numeric / 1000000.0)
        * p."inputTokenPricePerMillion"
      -- Cached input cost: cachedInputTokens at cached rate (fall back to input rate)
      + (COALESCE(l."cachedInputTokens", 0)::numeric / 1000000.0)
        * COALESCE(p."cachedInputTokenPricePerMillion", p."inputTokenPricePerMillion")
      -- Output cost
      + (COALESCE(l."completionTokens", 0)::numeric / 1000000.0)
        * p."outputTokenPricePerMillion"
      -- Search grounding cost
      + (COALESCE(l."searchGroundingRequests", 0)::numeric / 1000.0)
        * COALESCE(p."searchGroundingPricePerThousandRequests", 0)
    , 0)
  ) AS estimated_total_cost_usd
FROM "AIInteractionLogs" l
JOIN "AIModelPricings" p
  ON p.provider = l.provider
  AND p.model = l.model
  AND p."isActive" = true
  AND p."deletedDate" IS NULL
  AND p."validFrom" <= l."createdDate"
WHERE l."estimatedCostUsd" IS NULL
  AND l."promptTokens" IS NOT NULL
GROUP BY l.provider, l.model
ORDER BY records_to_update DESC;

-- ============================================================
-- Step 2: Backfill estimatedCostUsd using pricing data
-- ============================================================
-- Uses the most recent active pricing that was valid at the time
-- of each interaction (validFrom <= createdDate).
-- Only updates rows with token data and no existing cost.

UPDATE "AIInteractionLogs" l
SET "estimatedCostUsd" = sub.cost
FROM (
  SELECT
    l2."aiInteractionLogId",
    (
      -- Input tokens (excluding cached) at input rate
      (GREATEST(COALESCE(l2."promptTokens", 0) - COALESCE(l2."cachedInputTokens", 0), 0)::numeric / 1000000.0)
        * p."inputTokenPricePerMillion"
      -- Cached input tokens at cached rate (fallback to input rate)
      + (COALESCE(l2."cachedInputTokens", 0)::numeric / 1000000.0)
        * COALESCE(p."cachedInputTokenPricePerMillion", p."inputTokenPricePerMillion")
      -- Output tokens
      + (COALESCE(l2."completionTokens", 0)::numeric / 1000000.0)
        * p."outputTokenPricePerMillion"
      -- Search grounding
      + (COALESCE(l2."searchGroundingRequests", 0)::numeric / 1000.0)
        * COALESCE(p."searchGroundingPricePerThousandRequests", 0)
    ) AS cost
  FROM "AIInteractionLogs" l2
  JOIN LATERAL (
    SELECT *
    FROM "AIModelPricings" p2
    WHERE p2.provider = l2.provider
      AND p2.model = l2.model
      AND p2."isActive" = true
      AND p2."deletedDate" IS NULL
      AND p2."validFrom" <= l2."createdDate"
    ORDER BY p2."validFrom" DESC
    LIMIT 1
  ) p ON true
  WHERE l2."estimatedCostUsd" IS NULL
    AND l2."promptTokens" IS NOT NULL
) sub
WHERE l."aiInteractionLogId" = sub."aiInteractionLogId";

-- ============================================================
-- Step 3: Verify results
-- ============================================================
SELECT
  provider,
  model,
  COUNT(*) AS total_records,
  COUNT("estimatedCostUsd") AS records_with_cost,
  COUNT(*) - COUNT("estimatedCostUsd") AS records_still_missing_cost,
  ROUND(SUM("estimatedCostUsd")::numeric, 4) AS total_cost_usd,
  ROUND(AVG("estimatedCostUsd")::numeric, 6) AS avg_cost_per_call,
  ROUND(MIN("estimatedCostUsd")::numeric, 6) AS min_cost,
  ROUND(MAX("estimatedCostUsd")::numeric, 6) AS max_cost
FROM "AIInteractionLogs"
GROUP BY provider, model
ORDER BY total_cost_usd DESC;

-- Records still missing cost (no token data available)
SELECT COUNT(*) AS records_without_tokens_or_pricing
FROM "AIInteractionLogs"
WHERE "estimatedCostUsd" IS NULL;
