Gives all information about post/ comment (replies, votes, information about author etc.).

method: "bridge.get_discussion"
params:
{
  "auhtor":"{author}", "permlink":"permlink",
  
     author + permlink : mandatory, have to point to valid post; paging mechanism

  "observer":"{account}",

     optional (can be skipped or passed empty), when passed has to point to valid account
     used to hide authors blacklisted by observer

}
