Lists information about communities.

method: "bridge.list_communities"
params:
{
  "last":"{name}",

     optional, name of community; given community not appear in result; used for paging mechanism 

  "limit":"{number}",

    optional, range 1..100; default = 100

  "query":"{title}",

    optional, when given turns on filtering on given name/ part of name

  "sort": "{order}",

     optional, determines order of returned communities' default = "rank"
     values:
       "rank" - communities with highest rank (trending) score first
       "new" - newest communities first
       "subs" - communities with largest number of subscribers first

  "observer":"{account}",

     optional (can be skipped or passed empty), when passed has to point to valid account
     used to hide show relation between account and community (subscribed, role and title)

}
