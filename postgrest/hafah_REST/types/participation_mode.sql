SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_backend.participation_mode:
  type: string
  enum:
    - include
    - exclude
    - all

 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.participation_mode CASCADE;
CREATE TYPE hafah_backend.participation_mode AS ENUM (
    'include',
    'exclude',
    'all'
);
-- openapi-generated-code-end

RESET ROLE;
