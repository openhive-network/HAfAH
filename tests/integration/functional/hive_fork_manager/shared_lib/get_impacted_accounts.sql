DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN

    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}' :: jsonb :: hive.operation) ) = 2, 'Incorrect number of impacted accounts';
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{"type":"escrow_transfer_operation","value":{"from":"xtar","to":"testz","hbd_amount":{"amount":"0","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"1","precision":3,"nai":"@@000000021"},"escrow_id":123456,"agent":"fabien","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"","ratification_deadline":"2017-02-15T15:15:11","escrow_expiration":"2017-02-16T15:15:11"}}' :: jsonb :: hive.operation) ) = 3, 'Incorrect number of impacted accounts';
    -- Initminer:
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}' :: jsonb :: hive.operation) ) = 1, 'Incorrect number of impacted accounts';

END;
$BODY$
;


