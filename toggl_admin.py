#!/usr/bin/env python
import json
import urllib2
import base64
import sys
import datetime
from os.path import isfile

toggl_username = json.load(open('secrets.json'))['toggl']

class TZ(datetime.tzinfo):
    def utcoffset(self, dt): return datetime.timedelta(hours=0)
    def dst(self,dt): return datetime.timedelta(hours=0)

def get_response(url):
    password="api_token"
    auth_header = "Basic %s" % (base64.b64encode('%s:%s' % (toggl_username,password)))

    request = urllib2.Request( url )
    request.add_header("Authorization", auth_header)

    try:
        res = urllib2.urlopen(request)
        data = json.load(res)
    except IOError as e:
        print("OOps, something went wrong")
        print(e)
        sys.exit(1)

    return data

def get_stuff():
    return get_response("https://www.toggl.com/api/v8/me?with_related_data=true")

def dump(data):
    print(json.dumps(data, sort_keys=True, indent=4,
            separators=(',',': ')))

def dump_file(data, file):
    with open(file, 'w') as out:
        json.dump(data, out, sort_keys=True, indent=4, separators=(',',': '))

def load_file(file):
    with open(file, 'r') as f:
        return json.load(f)

def friday_of(dt):
    return dt + datetime.timedelta(days=(4 - dt.weekday()))

if __name__ == '__main__':
    data = get_stuff()
    data = data['data']

    projects = data['projects']
    clients  = data['clients']

    print "Projects without client"
    plookup = {}
    for p in projects:
        if p.has_key('cid'):
            cid = p['cid']
            if not plookup.has_key(cid):
                plookup[cid] = []
            plookup[cid].append(p)
        elif p['active']:
            print "    {} ({})".format(p['name'], p['id'])
        else:
            print "      ({})".format(p['name'])

    print "\n\n---\n"

    for c in clients:
        print "{} {}".format(c['name'],c['id'])
        cid = c['id']
        if plookup.has_key(cid):
            for p in plookup[cid]:
                print "    {}".format(p['name'])

