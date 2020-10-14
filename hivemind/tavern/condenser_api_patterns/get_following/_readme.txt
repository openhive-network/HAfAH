Gives accounts which given account follow.

method: "condenser_api.get_following"
params:
{
  "account":"{account}",

     mandatory, points on valid account

  "start":"{account}"

     optional, when given have to point on start account of following

  "limit:"{number}"

     mandatory, range of 1...1000;

  "follow_type":"{follow_type}"

     optional; default = 'blog'; other option 'ignore' to account which given account muted
}