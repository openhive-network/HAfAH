Lists blog's posts including reblogs.

method: "condenser_api.get_discussions_by_blog"
params:
{
  "tag":"{author}",

     mandatory, points to valid account

  "start_author":"{author}" + "start_permlink":"{permlink}",

     optional, when given have to point on valid start post

   "limit":"{number}",

     optional, range 1...100; default = 20

   "truncate_body":{number}

     optional, default = 0; 

   "filter_tags":"{list_of_tags}",

     optional, not supported
}