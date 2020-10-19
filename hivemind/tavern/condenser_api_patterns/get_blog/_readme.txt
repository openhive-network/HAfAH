Lists posts for given author from the most recent
(equivalent to get_discussions_by_blog, but uses offset-based pagination/ interface like get_blog_entries but returns more post references).
Entry_id and limit for paging mechanism.

method: "condenser_api.get_blog"
params:
{
  "account":"{account}"

     mandatory, points to valid account

  "start_entry_id":"{number}"

     optional; default = 0; when passed without limit must be lower than 500

  "limit":"{limit}"
     
     optional, range 0...500; default = "start_entry_id" + 1
}
