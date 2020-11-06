Lists replies made to author's posts.

method: "condenser_api.get_replies_by_last_update"
params:
{
  "start_author":"{author}",

     mandatory, point on author

  "start_permlink":"{permlink}",

     optional, when passed piont on valid post

  "limit":"{number}",

     optional range 1..100, default = 20

  "truncate_body":"{number}",

     optional, default = 0
}