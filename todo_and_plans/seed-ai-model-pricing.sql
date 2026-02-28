-- Seed AI Model Pricing Data
-- Run this AFTER the TokenPricing migration has created the AIModelPricings table.
-- Prices sourced from https://ai.google.dev/gemini-api/docs/pricing (February 2026)
-- All prices are per 1,000,000 tokens (USD) unless noted.

BEGIN;

-- Gemini 3 Flash Preview (most-used model)
INSERT INTO "AIModelPricings" (
  "provider", "model", "displayName",
  "inputTokenPricePerMillion", "outputTokenPricePerMillion",
  "cachedInputTokenPricePerMillion", "searchGroundingPricePerThousandRequests",
  "validFrom", "notes", "isActive"
) VALUES (
  'GEMINI', 'gemini-3-flash-preview', 'Gemini 3 Flash Preview',
  0.50, 3.00,
  0.05, 14.00,
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
  2.00, 12.00,
  0.20, 14.00,
  '2026-01-01T00:00:00Z',
  'Google pricing as of Feb 2026. Standard tier (prompts <= 200K tokens). Search grounding: $14/1K after 5K free/month.',
  true
);

COMMIT;

-- Verify
SELECT "aiModelPricingId", "provider", "model", "displayName",
       "inputTokenPricePerMillion", "outputTokenPricePerMillion",
       "cachedInputTokenPricePerMillion", "searchGroundingPricePerThousandRequests",
       "validFrom", "isActive"
FROM "AIModelPricings"
ORDER BY "provider", "model";
