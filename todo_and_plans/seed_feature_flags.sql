-- Seed Feature Flag permissions and initial flag
-- Run this AFTER the migration that creates the FeatureFlags table

-- 1. Insert permissions (idempotent via WHERE NOT EXISTS)
INSERT INTO "Permissions" ("permissionId", "name", "description", "permissionENUM")
SELECT gen_random_uuid(), v."name", v."description", v."permissionENUM"::text::"Permissions_permissionenum_enum"
FROM (VALUES
  ('Feature Flag Create', 'Create feature flags', 'FEATURE_FLAG_CREATE'),
  ('Feature Flag Read', 'Read feature flags', 'FEATURE_FLAG_READ'),
  ('Feature Flag Modify', 'Modify feature flags', 'FEATURE_FLAG_MODIFY'),
  ('Feature Flag Delete', 'Delete feature flags', 'FEATURE_FLAG_DELETE')
) AS v("name", "description", "permissionENUM")
WHERE NOT EXISTS (
  SELECT 1 FROM "Permissions" p WHERE p."permissionENUM"::text = v."permissionENUM"
);

-- 2. Assign all 4 permissions to SUPER_ADMIN role (idempotent)
INSERT INTO "RolePermissions" ("rolePermissionId", "roleId", "permissionId")
SELECT gen_random_uuid(), r."roleId", p."permissionId"
FROM "Roles" r
CROSS JOIN "Permissions" p
WHERE r."roleENUM" = 'SUPER_ADMIN'
  AND p."permissionENUM"::text IN ('FEATURE_FLAG_CREATE', 'FEATURE_FLAG_READ', 'FEATURE_FLAG_MODIFY', 'FEATURE_FLAG_DELETE')
  AND NOT EXISTS (
    SELECT 1 FROM "RolePermissions" rp
    WHERE rp."roleId" = r."roleId" AND rp."permissionId" = p."permissionId"
  );

-- 3. Insert initial LLM_ONLY_CLASSIFICATION flag (idempotent)
INSERT INTO "FeatureFlags" ("featureFlagId", "key", "enabled", "label", "description", "category", "isSystem", "createdDate", "updatedDate")
SELECT
  gen_random_uuid(),
  'LLM_ONLY_CLASSIFICATION',
  false,
  'LLM-Only Classification',
  'Use LLM for all service type classification instead of keyword matching. Improves accuracy for ambiguous queries like "radon mitigation contractor" but adds latency.',
  'AI',
  false,
  NOW(),
  NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM "FeatureFlags" f WHERE f."key" = 'LLM_ONLY_CLASSIFICATION'
);
