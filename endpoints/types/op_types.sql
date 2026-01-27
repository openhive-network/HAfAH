SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_backend.op_types:
  type: object
  properties:
    op_type_id:
      type: integer
      description: operation type id
    operation_name:
      type: string
      description: operation type name
    is_virtual:
      type: boolean
      description: true if operation is virtual
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.op_types CASCADE;
CREATE TYPE hafah_backend.op_types AS (
    "op_type_id" INT,
    "operation_name" TEXT,
    "is_virtual" BOOLEAN
);
-- openapi-generated-code-end

/** openapi:components:schemas
hafah_backend.operation_group_types:
  type: string
  enum:
    - virtual
    - real
    - all
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.operation_group_types CASCADE;
CREATE TYPE hafah_backend.operation_group_types AS ENUM (
    'virtual',
    'real',
    'all'
);
-- openapi-generated-code-end

RESET ROLE;
