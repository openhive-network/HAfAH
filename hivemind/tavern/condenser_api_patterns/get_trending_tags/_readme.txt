Lists tags sort by all payout, with stats summary of comments and top_posts.

method: "condenser_api.get_trending_tags"
params:
{
  "start_tag":"{tag}",

     optional, point to tag; paging mechanism

  "limit":{number},

     optional range 1...250; default = 250
}