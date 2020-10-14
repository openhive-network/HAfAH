Lists posts sorted by promoted amount.

method: "condenser_api.get_discussions_by_promoted"
params:
{
  "start_author":"{author}" + "start_permlink":"{permlink}",

     optional, should point to valid apost

   "limit":"{number}",

     optional, range 1...100; default = 20

    "tag":"{account}",

     optional, turns on filtering for posts with given tag

   "truncate_body":{number}

     optional, default = 0; 

   "filter_tags":"{list_of_tags}",

     optional, not supported
}