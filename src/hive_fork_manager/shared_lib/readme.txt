*****Usage*****
select * from get_impacted_accounts('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}')

*****Result*****
"admin"
"steemit"
