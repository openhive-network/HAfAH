Lists blog's posts including reblogs.
Call implemented in condenser_api.

method: "tags_api.get_discussions_by_blog"
params:
{
  "tag":"{author}",

     mandatory, points to valid account

  "author":"{author}" + "start_permlink":"{permlink}",

     optional, when given have to point on valid start post

   "limit":"{number}",

     optional, range 1...100; default = 20

   "truncate_body":{number}

     optional, default = 0; 

}
