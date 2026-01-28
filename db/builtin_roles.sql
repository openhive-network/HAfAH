/**
 * Database Roles for HAfAH (HAF Account History)
 * ===============================================
 *
 * This file defines the two database roles required by HAfAH:
 *
 * hafah_owner
 * -----------
 * - Owner role with full read/write access to all HAfAH schemas
 * - Used by: Installation scripts, schema migrations
 * - Inherits from: hive_applications_owner_group (HAF role for app owners)
 * - Can create schemas, tables, functions
 *
 * hafah_user
 * ----------
 * - Read-only role for API access
 * - Used by: PostgREST (API server), read-only queries
 * - Inherits from: hive_applications_group (HAF role for app users)
 * - Has 15-second query timeout to prevent runaway queries
 * - Can only SELECT from tables, cannot modify data
 *
 * Role Hierarchy:
 * ---------------
 *   haf_admin
 *       └── hafah_owner (schema owner, used for install/migrations)
 *               └── hafah_user (PostgREST service user, read-only)
 *
 * Security Model:
 * ---------------
 * - All schema objects are owned by hafah_owner
 * - hafah_user is granted SELECT on tables after installation
 * - PostgREST connects as hafah_user for safe API access
 * - HAfAH is read-only (no block processing), so hafah_owner
 *   is only used during installation
 */

-- Create schema owner role (used for installation and migrations)
DO $$
BEGIN
  CREATE ROLE hafah_owner WITH LOGIN INHERIT IN ROLE hive_applications_owner_group;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;

-- Create API user role (read-only access via PostgREST)
DO $$
BEGIN
  CREATE ROLE hafah_user WITH LOGIN INHERIT IN ROLE hive_applications_group;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;

-- Allow haf_admin to act as hafah_owner (for installation scripts)
GRANT hafah_owner TO haf_admin;

-- Allow hafah_owner to act as hafah_user (for testing)
GRANT hafah_user TO hafah_owner;

-- Limit API query execution time to prevent resource exhaustion
-- 15s allows for high-concurrency benchmark scenarios while still protecting against runaway queries
ALTER ROLE hafah_user SET statement_timeout = '15s';
