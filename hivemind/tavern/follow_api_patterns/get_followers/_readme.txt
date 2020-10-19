Gives accounts which follow given account.
Call implementation in condenser_api.

method: "follow_api.get_followers"
params:
{
  "account":"{account}",

     mandatory, points on valid account

  "start":"{account}"

     optional, when given have to point on start account of followers

  "limit:"{number}"

     mandatory, range of 1...1000;

  "follow_type":"{follow_type}"

     optional; default = 'blog'; other option 'ignore' to account which muted given account
}
