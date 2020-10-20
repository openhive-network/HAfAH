Lists account's replies.
Call implemented in condenser_api.

method: "tags_api.get_discussions_by_comments"
params:
{
  "start_author":"{author}",

     mandatory, points to valid account

  "start_permlink":"{permlink}",

     optional, when given have to point on valid start comment

   "limit":"{number}",

     optional, range 1...100; default = 20

   "truncate_body":{number}

     optional, default = 0; 

   "filter_tags":"{list_of_tags}",

     optional, not supported
}
