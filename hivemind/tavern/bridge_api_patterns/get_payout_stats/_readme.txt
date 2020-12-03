Lists communities order by payout with stats (total payout, number of posts and authors).
Similar to condenser_api.get_trending_tags but gives slightly different values and it is limited to communities.

method: "bridge.get_payout_stats"
params:
{
  "limit":"{number}",

     optional, range 1..250; default = 250

}
