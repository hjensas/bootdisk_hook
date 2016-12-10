#!/usr/bin/python2
import sys
import json

data = json.loads(sys.stdin.readline() or '{}')
if not len(sys.argv) is 2:
  print "One argument is required"
  quit()
keys = sys.argv[1].split('.')
for key in keys:
  data = data.get(key)
  if data is None:
    print "key does is not exist"
    quit(1)
print data
quit()
