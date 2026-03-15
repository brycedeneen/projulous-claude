-- =============================================================================
-- SP Review Permission Seed Script
-- =============================================================================
-- Seeds SP Review permissions and assigns them to appropriate roles.
-- Idempotent — safe to run multiple times.
--
-- Permission assignments:
--   - SP_REVIEW_CREATE: CUSTOMER + SUPER_ADMIN
--   - SP_REVIEW_READ: CUSTOMER + SERVICE_PROVIDER + SUPER_ADMIN
--   - SP_REVIEW_DELETE: CUSTOMER + SUPER_ADMIN
--   - SP_REVIEW_MODERATE: SUPER_ADMIN only
--   - SP_REVIEW_RESPOND: SERVICE_PROVIDER + SUPER_ADMIN
--   - SP_REVIEW_FLAG: CUSTOMER + SUPER_ADMIN
--
-- Usage:
--   psql -f seed_sp_review_permissions.sql
--   Or run via MCP db tool / any Postgres client
-- =============================================================================

BEGIN;

-- Step 1: Insert missing SP Review permission rows
INSERT INTO "Permissions" ("permissionENUM", "name", "description", "createdDate", "updatedDate")
SELECT v."permissionENUM", v."name", v."description", now(), now()
FROM (VALUES
  ('SP_REVIEW_CREATE'::"Permissions_permissionenum_enum", 'Create SP Review', 'Create reviews for service providers'),
  ('SP_REVIEW_READ'::"Permissions_permissionenum_enum", 'Read SP Review', 'Read reviews for service providers'),
  ('SP_REVIEW_DELETE'::"Permissions_permissionenum_enum", 'Delete SP Review', 'Delete own reviews for service providers'),
  ('SP_REVIEW_MODERATE'::"Permissions_permissionenum_enum", 'Moderate SP Review', 'Moderate/admin reviews for service providers'),
  ('SP_REVIEW_RESPOND'::"Permissions_permissionenum_enum", 'Respond to SP Review', 'Respond to reviews as a service provider'),
  ('SP_REVIEW_FLAG'::"Permissions_permissionenum_enum", 'Flag SP Review', 'Flag inappropriate reviews for moderation')
) AS v("permissionENUM", "name", "description")
WHERE NOT EXISTS (
  SELECT 1 FROM "Permissions" p
  WHERE p."permissionENUM" = v."permissionENUM"
    AND p."deletedDate" IS NULL
);

-- Step 2: Assign SP Review permissions to CUSTOMER role
INSERT INTO "RolePermissions" ("roleId", "permissionId", "createdDate", "updatedDate")
SELECT r."roleId", p."permissionId", now(), now()
FROM "Roles" r, "Permissions" p
WHERE r."roleENUM" = 'CUSTOMER'
  AND r."deletedDate" IS NULL
  AND p."permissionENUM" IN ('SP_REVIEW_CREATE', 'SP_REVIEW_READ', 'SP_REVIEW_DELETE', 'SP_REVIEW_FLAG')
  AND p."deletedDate" IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM "RolePermissions" rp
    WHERE rp."roleId" = r."roleId"
      AND rp."permissionId" = p."permissionId"
      AND rp."deletedDate" IS NULL
  );

-- Step 3: Assign SP Review permissions to SERVICE_PROVIDER role
INSERT INTO "RolePermissions" ("roleId", "permissionId", "createdDate", "updatedDate")
SELECT r."roleId", p."permissionId", now(), now()
FROM "Roles" r, "Permissions" p
WHERE r."roleENUM" = 'SERVICE_PROVIDER'
  AND r."deletedDate" IS NULL
  AND p."permissionENUM" IN ('SP_REVIEW_RESPOND', 'SP_REVIEW_READ')
  AND p."deletedDate" IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM "RolePermissions" rp
    WHERE rp."roleId" = r."roleId"
      AND rp."permissionId" = p."permissionId"
      AND rp."deletedDate" IS NULL
  );

-- Step 4: Assign all SP Review permissions to SUPER_ADMIN role
INSERT INTO "RolePermissions" ("roleId", "permissionId", "createdDate", "updatedDate")
SELECT r."roleId", p."permissionId", now(), now()
FROM "Roles" r, "Permissions" p
WHERE r."roleENUM" = 'SUPER_ADMIN'
  AND r."deletedDate" IS NULL
  AND p."permissionENUM" IN ('SP_REVIEW_CREATE', 'SP_REVIEW_READ', 'SP_REVIEW_DELETE', 'SP_REVIEW_MODERATE', 'SP_REVIEW_RESPOND', 'SP_REVIEW_FLAG')
  AND p."deletedDate" IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM "RolePermissions" rp
    WHERE rp."roleId" = r."roleId"
      AND rp."permissionId" = p."permissionId"
      AND rp."deletedDate" IS NULL
  );

COMMIT;

-- =============================================================================
-- Verification Queries (for manual checking)
-- =============================================================================
-- Uncomment these to verify the seeding worked correctly:

-- SELECT COUNT(*) as sp_review_permissions
-- FROM "Permissions"
-- WHERE "permissionENUM" LIKE '%SP_REVIEW%' AND "deletedDate" IS NULL;

-- SELECT r."roleENUM", COUNT(rp."rolePermissionId") as sp_review_perm_count
-- FROM "Roles" r
-- LEFT JOIN "RolePermissions" rp ON r."roleId" = rp."roleId" AND rp."deletedDate" IS NULL
-- LEFT JOIN "Permissions" p ON p."permissionId" = rp."permissionId" AND p."deletedDate" IS NULL
-- WHERE r."deletedDate" IS NULL AND (p."permissionENUM" LIKE '%SP_REVIEW%' OR p."permissionENUM" IS NULL)
-- GROUP BY r."roleENUM"
-- ORDER BY r."roleENUM";

-- SELECT r."roleENUM", array_agg(p."permissionENUM" ORDER BY p."permissionENUM") as sp_review_permissions
-- FROM "RolePermissions" rp
-- JOIN "Roles" r ON r."roleId" = rp."roleId"
-- JOIN "Permissions" p ON p."permissionId" = rp."permissionId"
-- WHERE rp."deletedDate" IS NULL AND r."deletedDate" IS NULL AND p."deletedDate" IS NULL
--   AND p."permissionENUM" LIKE '%SP_REVIEW%'
-- GROUP BY r."roleENUM"
-- ORDER BY r."roleENUM";