Lists posts for given author from the most recent
(interface identical to get_blog, but returns minimalistic post references).
Entry_id and limit for paging mechanism (start_entry_id can be at least smaller one than limit [start_index - limit + 1 >= 0])

method: "condenser_api.get_blog_entries"
params:
{
  "author":"{author}"

     mandatory, points to valid account

  "start_entry_id":"{number}"

     optional; default = 0

  "limit":"{limit}"
     
     optional, range 1...500; default = "start_entry_id" + 1
}
