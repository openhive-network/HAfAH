Lists posts pending on payout.
Similar to bridge.get_ranked_posts with sort by payout.

method: "condenser_api.get_post_discussions_by_payout"
params:
{
  "start_author":"{author}" + "start_permlink":"{permlink}",

     optional, when given have to point on post; paging mechanism

  "limit:"{number}",

     optional, default = 20 range of 1...1000

  "tag":"{tag}",

     optional; turns on filtering for posts with given tag

   "truncate_body":"{number}",

     optional, default = 0
}