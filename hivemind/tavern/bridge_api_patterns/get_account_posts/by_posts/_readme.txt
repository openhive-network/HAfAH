Gets a list of root posts.

method: "bridge_api.get_account_posts"
params:
{
  "params": ["{account}","{sort}","{start_author}","{start_permlink}","{limit}"],

     account :                        [string] mandatory blogger's account
     sort :                           [string] mandatory possible values['blog', 'feed', 'posts', 'comments', 'replies', 'payout'] - here 'posts'
     start_author + start_permlink :  [string] optional (can be left blank), when given have to point to valid post; paging mechanism
     limit :                          [number] optional (by default 20)
}