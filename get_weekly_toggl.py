#!/usr/bin/env python
import json
import urllib2
import base64
import sys
import datetime
from os.path import isfile

toggl_username = json.load(open('config.json'))['secrets']['toggl']

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

client_infos = {}
def get_client_info(cid):
    if not client_infos.has_key(cid):
        url = "https://www.toggl.com/api/v8/clients/%s" % cid
        data = get_response(url)
        client_infos[cid] = data['data']

    return client_infos[cid]


project_infos = {}
def get_project_info(pid):
    if not project_infos.has_key(pid):
        url = "https://www.toggl.com/api/v8/projects/%s" % pid
        data = get_response(url)
        data = data['data']
        if data.has_key('cid'):
            client = get_client_info(data['cid'])
            data['client'] = client['name']
        else:
            data['client'] = ''
        project_infos[pid] = data

    return project_infos[pid]


def check_week_of(day):
    saturday = day - datetime.timedelta(
                days=day.weekday() + 2, # Saturday
                microseconds=day.microsecond,
                hours=day.hour)
    friday = saturday + datetime.timedelta(
            days = 6)
    url = "https://www.toggl.com/api/v8/time_entries?start_date=%s&end_date=%s" % (
            urllib2.quote(saturday.isoformat()),
            urllib2.quote(friday.isoformat()))

    data = get_response(url)

    ## sums["client:projname:entry descr:tag"] = total time
    sums = {}
    for entry in data:
        if entry['duration'] == 0:
            continue
        tag = 'None'
        if entry.has_key('tags'):
            tag = ' / '.join(entry['tags'])
        if entry.has_key('pid'):
            project = get_project_info(entry['pid'])
            desc = "%s:%s:%s:%s" % ( project['client'], project['name'], entry.get('description', ""), tag )
        else:
            desc = "None:None:%s:%s" % ( entry.get('description',""), tag )
        if not sums.has_key(desc):
            sums[desc] = 0.0
        if entry['duration'] > 0:
            sums[desc] += entry['duration']/3600.0

    return sums

def dump(data):
    print(json.dumps(data, sort_keys=True, indent=4,
            separators=(',',': ')))

def dump_file(data, file):
    with open(file, 'w') as out:
        json.dump(data, out, sort_keys=True, indent=4, separators=(',',': '))

def friday_of(dt):
    return dt + datetime.timedelta(days=(4 - dt.weekday()))

if __name__ == '__main__':
    now = datetime.datetime.now(TZ())
    for delta in [0,1,2,3]:
        check_time = now - datetime.timedelta(days=7*delta)
        friday = friday_of(check_time).strftime("%Y-%m-%d")

        outfile = 'json/info_{}.json'.format(friday)

        if isfile(outfile):
            print "We already have checked {}, skipping".format(friday)
            continue

        print "Processing {}".format(friday)

        hours = check_week_of(check_time)
        sum = 0
        for hour in hours.values():
            sum += hour
        info = {
            "week": friday,
            "sum": sum,
            "work": hours,
        }
        dump_file(info, outfile)
