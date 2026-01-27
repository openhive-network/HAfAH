SET ROLE hafah_owner;

/** openapi:components:schemas
hafah_backend.nai_object:
  type: object
  properties:
    nai:
      type: string
      description: String representation of a NAI (Network Asset Identifier)
    amount:
      type: string
      description: Amount of the asset
    precision:
      type: integer
      description: Precision of the asset
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.nai_object CASCADE;
CREATE TYPE hafah_backend.nai_object AS (
    "nai" TEXT,
    "amount" TEXT,
    "precision" INT
);
-- openapi-generated-code-end

/** openapi:components:schemas
hafah_backend.fill_order:
  type: object
  properties:
    current_pays:
      $ref: '#/components/schemas/hafah_backend.nai_object'
    date:
      type: string
      format: date-time
    maker:
      type: string
    open_pays:
      $ref: '#/components/schemas/hafah_backend.nai_object'
    taker:
      type: string
 */
-- openapi-generated-code-begin
DROP TYPE IF EXISTS hafah_backend.fill_order CASCADE;
CREATE TYPE hafah_backend.fill_order AS (
    "current_pays" hafah_backend.nai_object,
    "date" TIMESTAMP,
    "maker" TEXT,
    "open_pays" hafah_backend.nai_object,
    "taker" TEXT
);
-- openapi-generated-code-end

/** openapi:components:schemas
hafah_backend.array_of_fill_order:
  type: array
  items:
    $ref: '#/components/schemas/hafah_backend.fill_order'
*/

RESET ROLE;
