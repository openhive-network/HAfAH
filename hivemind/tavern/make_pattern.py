#!/usr/bin/env python3

# script to replace typical differences in .orig file with help of new .out file to form likely .pat file
# works only for files with posts; posts are not reordered - that step has to be done manually when needed (and verified if new order is correct)
# usage: ./make_pattern.py test.orig.json test.out.json test.pat.json

import sys
import json
import os
from decimal import Decimal


def load_file(path:str):
  ret = {}
  with open(path, 'r') as f:
    ret = json.load(f)
  return ret

def save_file(path:str, result:dict):
  with open(path, 'w') as f:
    f.write(json.dumps(result, sort_keys=True, indent=2))
    f.write("\n")


def map_votes(votes:list):
  mapped = {}
  for vote in votes:
    key = vote['voter']
    assert not key in mapped, "Duplicated vote"
    mapped[key] = vote
  return mapped

def map_posts(posts:list):
  mapped = {}
  for post in posts:
    key = post['author'] + '/' + post['permlink']
    assert not key in mapped, "Duplicated post"
    mapped[key] = post
  return mapped


def match_value(key,output,pattern):
  if key in output:
    assert key in pattern, "Incompatible .orig/.out files"
    output[key] = pattern[key]

def process_vote(vote):
  if 'rshares' in vote:
    vote['rshares'] = int(vote['rshares'])
  if 'weight' in vote:
    vote['weight'] = int(vote['weight'])

def match_vote(vote,new_version):
  match_value('reputation',vote,new_version)

def process_post(post):
  if 'comment' in post: # condenser_api.get_blog
    post = post['comment']
  if 'percent_steem_dollars' in post:
    post['percent_hbd'] = post['percent_steem_dollars']
    del post['percent_steem_dollars']
  if 'json_metadata' in post and isinstance(post['json_metadata'],str): # in bridge_api it is a dict
    post['json_metadata'] = post['json_metadata'].replace('\\/','/')

def match_post(post,new_version):
  if 'active_votes' in post:
    assert 'active_votes' in new_version, "Incompatible .orig/.out files"
    vote_map = map_votes(new_version['active_votes'])
    for vote in post['active_votes']:
      process_vote(vote)
      key = vote['voter']
      if key in vote_map:
        match_vote(vote,vote_map[key])
      else:
        print("No matching vote found for @%s" % key)
        
  match_value('author_reputation',post,new_version)
  match_value('cashout_time',post,new_version)
  match_value('post_id',post,new_version)
  match_value('id',post,new_version)
  match_value('pending_payout_value',post,new_version)

def main():
  if len(sys.argv) != 4 and len(sys.argv) != 5:
    print( "Usage: __name__ input_orig_path input_out_path output_pat_path [reorder_field]" )
    exit ()

  orig = load_file(sys.argv[1])
  out = load_file(sys.argv[2])
  if os.path.exists(sys.argv[3]):
    os.remove(sys.argv[3])

  if isinstance(orig,list):
    assert isinstance(out,list), "Incompatible .orig/.out files"
    pat = []
    post_map = map_posts(out)
    for post in orig:
      process_post(post)
      pat.append(post)
      key = post['author'] + '/' + post['permlink']
      if key in post_map:
        match_post(post,post_map[key])
      else:
        print("No matching post found for @%s" % key)
      
  elif isinstance(orig,dict):
    assert isinstance(out,dict), "Incompatible .orig/.out files"
    pat = {}
    assert False, "Processing of single post patterns not implemented yet"
  else:
    assert False, "Unrecognized post format"

  if len(sys.argv) == 5 and len(pat) > 0:
    id_sort = None
    if 'id' in pat[0]: # database_api
      id_sort = 'id'
    elif 'post_id' in pat[0]: # bridge_api, condenser_api
      id_sort = 'post_id'
    if id_sort:
      pat.sort(key=lambda post: post[id_sort], reverse=True)
    sort_field = sys.argv[4]
    if sort_field == 'pending_payout_value' or sort_field == 'promoted':
      pat.sort(key=lambda post: Decimal(post[sort_field][0:-4]), reverse=True)
    else:
      pat.sort(key=lambda post: post[sort_field], reverse=True)

  save_file(sys.argv[3],pat)
  exit (0)

if __name__ == "__main__":
  main()