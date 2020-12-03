Lists given community account-roles (anyone with non-guest status).

method: "bridge.list_community_roles"
params:
{
  "community":"{name}",

    mandatory, points to community

  "last":"{name}",

    optional, paging mechanism (broken - most likely was meant to point to account)

  "limit":{number}

    optional, unspecified range, default = 50 (to be changed - needs to enforce positive integer within range that also needs to be defined)

}