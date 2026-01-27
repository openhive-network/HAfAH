SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_backend.sort_direction:
  type: string
  enum:
    - asc
    - desc
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.sort_direction CASCADE;
CREATE TYPE hafah_backend.sort_direction AS ENUM (
    'asc',
    'desc'
);
-- openapi-generated-code-end

RESET ROLE;
