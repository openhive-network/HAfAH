Lists given community account-roles (anyone with non-guest status).

method: "bridge.list_community_roles"
params:
{
  "community":"{name}",

    mandatory, points to community

  "last":"{name}",

     optional, appears to be broken 

  "limit":"{number}",

    optional, must be positive; default = 50;

}