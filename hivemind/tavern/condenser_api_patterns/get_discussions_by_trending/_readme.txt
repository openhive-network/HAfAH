Lists posts sorted by trending score [sc_trend desc] (similar to the by_hot sorting, but with longer period of time).

method: "condenser_api.get_discussions_by_trending"
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