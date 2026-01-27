SET ROLE hafah_owner;

/*
 * account.sql: Account lookup utilities.
 *
 * Functions:
 *   - hafah_backend.get_account_id() - Get account ID from name with validation
 *   - hafah_backend.get_account_name() - Get account name from ID
 */

/*
 * ===================================================================================
 * get_account_id
 * ===================================================================================
 * PURPOSE: Retrieves account ID for a given account name with optional validation.
 *
 * PARAMETERS:
 *   _account_name - Name of the account to look up
 *   _required     - If TRUE, raises exception when account not found
 *
 * RETURNS: INT - account ID, or NULL if not found and not required
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_account_id(
    _account_name    TEXT,
    _required        BOOLEAN
)
RETURNS INT
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
  __account_id INT := (SELECT av.id FROM hive.accounts_view av WHERE av.name = _account_name);
BEGIN
  PERFORM hafah_backend.validate_account(__account_id, _account_name, _required);
  RETURN __account_id;
END
$$;

/*
 * ===================================================================================
 * get_account_name
 * ===================================================================================
 * PURPOSE: Retrieves account name for a given account ID.
 *
 * PARAMETERS:
 *   _account_id - ID of the account to look up
 *
 * RETURNS: TEXT - account name
 */
CREATE OR REPLACE FUNCTION hafah_backend.get_account_name(
    _account_id    INT
)
RETURNS TEXT
LANGUAGE 'plpgsql' STABLE
AS $$
BEGIN
  RETURN av.name FROM hive.accounts_view av WHERE av.id = _account_id;
END
$$;

RESET ROLE;
