/**
 * HAfAH Core Application Schema
 * =============================
 *
 * This file defines the core HAfAH HAF application, including:
 * - Schema creation for hafah_backend and hafah_endpoints
 * - Version tracking table
 * - Helper views for operation queries
 *
 * Schema Structure:
 * -----------------
 * hafah_backend:
 *   - Contains backend implementation functions
 *   - Argument parsing and validation utilities
 *   - Exception handling functions
 *   - Helper views for joining operation data
 *
 * hafah_endpoints:
 *   - Contains PostgREST-exposed API functions
 *   - JSON-RPC dispatcher (home function)
 *   - REST endpoint functions
 *
 * Core Objects:
 * -------------
 * 1. version: Schema version tracking table
 * 2. helper_operations_view: Joins operations with types for query efficiency
 *
 * Note: HAfAH is a read-only application that reads directly from HAF
 * base tables. It has NO processing functions and NO application tables
 * (except version tracking).
 *
 * @see builtin_roles.sql for database role definitions
 */

SET ROLE hafah_owner;

-- ============================================================================
-- SCHEMA CREATION
-- ============================================================================
-- Drop and recreate schemas for clean installation

DROP SCHEMA IF EXISTS hafah_endpoints CASCADE;
DROP SCHEMA IF EXISTS hafah_backend CASCADE;

CREATE SCHEMA IF NOT EXISTS hafah_backend AUTHORIZATION hafah_owner;
CREATE SCHEMA IF NOT EXISTS hafah_endpoints AUTHORIZATION hafah_owner;

-- ============================================================================
-- VERSION TABLE
-- ============================================================================
-- Tracks the installed version of HAfAH for compatibility checks

CREATE TABLE hafah_backend.version(
  git_hash TEXT
);
INSERT INTO hafah_backend.version VALUES('unspecified (generate and apply set_version_in_sql.pgsql)');

-- ============================================================================
-- HELPER VIEWS
-- ============================================================================
-- Views that join base HAF tables for efficient operation queries

/**
 * helper_operations_view
 * ----------------------
 * Joins hive.operations_view with operation types to provide
 * virtual operation flag without repeated joins in query functions.
 *
 * Columns:
 *   id          - Operation ID
 *   block_num   - Block containing the operation
 *   trx_in_block - Transaction index within block
 *   op_pos      - Operation position within transaction
 *   virtual_op  - TRUE if this is a virtual operation
 *   op_type_id  - Operation type ID
 *   body        - Operation body as JSON
 *   body        - Operation body as JSONB (full wrapper with type)
 */
CREATE VIEW hafah_backend.helper_operations_view AS SELECT
  hov.id id,
  block_num block_num,
  trx_in_block trx_in_block,
  hov.op_pos ::BIGINT AS op_pos,
  hot.is_virtual AS virtual_op,
  op_type_id op_type_id,
  hov.body AS body
FROM
  hive.operations_view hov
JOIN
  hafd.operation_types hot
ON
  hov.op_type_id=hot.id
;

RESET ROLE;
