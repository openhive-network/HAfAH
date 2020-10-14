Lists discussions based on payout sort.

method: "condenser_api.get_comment_discussion_by_payout"
params:
{
  "author":"{author}"

     optional, points to valid start account

  "permlink":"{permlink}"

     optional, with author when given have to point to valid start post; paging mechanism

  "limit":"{limit}"

     optional, range 1...500; default = 20

   "tag":"{tag}"

     optional, when given have to point on valid tag

   "truncate_body":{number}

     optional, default = 0; 
}