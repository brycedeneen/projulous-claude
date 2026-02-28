-- =============================================================================
-- AI Cost Tracking: Post-Migration Seed Script for Production
-- =============================================================================
-- Run this AFTER the TokenPricing1772238414870 migration has executed.
-- The migration creates the AIModelPricings table, adds columns to
-- AIInteractionLogs, and updates the Postgres enum types.
--
-- This script seeds:
--   1. Permission rows (4 new AI_MODEL_PRICING permissions)
--   2. Initial model pricing data (Gemini models currently in use)
-- =============================================================================

BEGIN;

-- ============================================
-- 1. Seed Permission Rows
-- ============================================
-- The migration adds the enum values. This inserts the actual rows.

INSERT INTO "Permissions" ("permissionENUM", "name", "description")
SELECT v."permissionENUM", v."name", v."description"
FROM (VALUES
  ('AI_MODEL_PRICING_CREATE'::"Permissions_permissionenum_enum", 'AI Model Pricing Create', 'Create AI model pricing records'),
  ('AI_MODEL_PRICING_READ'::"Permissions_permissionenum_enum", 'AI Model Pricing Read', 'Read AI model pricing records'),
  ('AI_MODEL_PRICING_MODIFY'::"Permissions_permissionenum_enum", 'AI Model Pricing Modify', 'Modify AI model pricing records'),
  ('AI_MODEL_PRICING_DELETE'::"Permissions_permissionenum_enum", 'AI Model Pricing Delete', 'Delete AI model pricing records')
) AS v("permissionENUM", "name", "description")
WHERE NOT EXISTS (
  SELECT 1 FROM "Permissions" p
  WHERE p."permissionENUM" = v."permissionENUM"
    AND p."deletedDate" IS NULL
);

-- ============================================
-- 2. Seed Initial Model Pricing Data
-- ============================================
-- Prices sourced from https://ai.google.dev/gemini-api/docs/pricing (Feb 2026)
-- All prices are per 1,000,000 tokens (USD) unless noted.

-- Gemini 3 Flash Preview (primary model, ~1500 logged interactions)
INSERT INTO "AIModelPricings" (
  "provider", "model", "displayName",
  "inputTokenPricePerMillion", "outputTokenPricePerMillion",
  "cachedInputTokenPricePerMillion", "searchGroundingPricePerThousandRequests",
  "validFrom", "notes", "isActive"
) VALUES (
  'GEMINI', 'gemini-3-flash-preview', 'Gemini 3 Flash Preview',
  0.500000, 3.000000,
  0.050000, 14.000000,
  '2026-01-01T00:00:00Z',
  'Google pricing as of Feb 2026. Text/image/video input rate. Search grounding: $14/1K after 5K free/month.',
  true
);

-- Gemini 3.1 Pro Preview
INSERT INTO "AIModelPricings" (
  "provider", "model", "displayName",
  "inputTokenPricePerMillion", "outputTokenPricePerMillion",
  "cachedInputTokenPricePerMillion", "searchGroundingPricePerThousandRequests",
  "validFrom", "notes", "isActive"
) VALUES (
  'GEMINI', 'gemini-3.1-pro-preview', 'Gemini 3.1 Pro Preview',
  2.000000, 12.000000,
  0.200000, 14.000000,
  '2026-01-01T00:00:00Z',
  'Google pricing as of Feb 2026. Standard tier (prompts <= 200K tokens). Search grounding: $14/1K after 5K free/month.',
  true
);

COMMIT;

-- ============================================
-- 3. Verify
-- ============================================

-- Verify permissions
SELECT "permissionId", "permissionENUM", "name"
FROM "Permissions"
WHERE "permissionENUM"::text LIKE 'AI_MODEL%'
  AND "deletedDate" IS NULL
ORDER BY "permissionENUM";

-- Verify pricing
SELECT "aiModelPricingId", "provider", "model", "displayName",
       "inputTokenPricePerMillion", "outputTokenPricePerMillion",
       "cachedInputTokenPricePerMillion", "searchGroundingPricePerThousandRequests",
       "validFrom", "isActive"
FROM "AIModelPricings"
WHERE "deletedDate" IS NULL
ORDER BY "provider", "model";
