Lists posts for given author from the most recent
(interface identical to get_blog, but returns minimalistic post references).
Entry_id and limit for paging mechanism.

method: "condenser_api.get_blog_entries"
params:
{
  "account":"{account}"

     mandatory, points to valid account

  "start_entry_id":"{number}"

     optional; default = 0;  when passed without limit must be lower than 500

  "limit":"{limit}"
     
     optional, range 1...500; default = "start_entry_id" + 1
}
