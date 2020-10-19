Lists posts for given author from the most recent
(equivalent to get_discussions_by_blog, but uses offset-based pagination/ interface like get_blog_entries but returns more post references).
Entry_id and limit for paging mechanism.
Call implementation in condenser_api.

method: "follow_api.get_blog"
params:
{
  "author":"{author}"

     mandatory, points to account

  "start_entry_id":"{number}"

     optional, default = 0; if it is passed without limit must be smaller than 500

  "limit":"{limit}"
     
     optional, range 0...500; default = "start_entry_id" + 1
}
