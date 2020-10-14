Lists posts created/reblogged by those followed by selected account.
Gives posts that were created/reblogged within last month.

method: "condenser_api.get_discussions_by_feed"
params:
{
  "tag":"{account}",

   mandatory, have to point on valid account whose feed we are looking at

  "start_author":"{author}" + "start_permlink":"{permlink}",

     optional, should point to valid apost

   "limit":"{number}",

     optional, range 1...100; default = 20

   "truncate_body":{number}

     optional, default = 0; 

   "filter_tags":"{list_of_tags}",

     optional, not supported
}