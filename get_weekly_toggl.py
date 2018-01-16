#!/usr/bin/env python2
import json
import urllib2
import base64
import sys
import datetime
from os.path import isfile
import os
import argparse

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
                minutes=day.minute,
                seconds=day.second,
                hours=day.hour) # saturday 00:00:00
    friday = saturday + datetime.timedelta(
            days = 7) # changed to 7 to set the end date to midnight Saturday 
    url = "https://www.toggl.com/api/v8/time_entries?start_date=%s&end_date=%s" % (
            urllib2.quote(saturday.isoformat()),
            urllib2.quote(friday.isoformat()))

    data = get_response(url)

    ## sums["client:projname:entry descr:tag"] = total time
    entries = {}
    for entry in data:
        myentry = {
                'client': 'None',
                'project': 'None',
                'description': '',
                'tag': '',
                'duration': 0,
        }
        if entry['duration'] == 0:
            continue
        if entry.has_key('tags'):
            myentry['tag'] = ' / '.join(entry['tags'])
        if entry.has_key('pid'):
            project =  get_project_info(entry['pid'])
            myentry['project'] = project['name']
            myentry['client'] = project['client']
            myentry['description'] = entry.get('description','')
        if entry['duration'] > 0:
            myentry['duration'] = entry['duration']/3600.0
        hash = ':'.join( [ myentry[k] for k in ['client', 'project', 'description', 'tag'] ] )

        if entries.has_key(hash):
            entries[hash]['duration'] += myentry['duration']
        else:
            entries[hash] = myentry


    return entries

def dump(data):
    print(json.dumps(data, sort_keys=True, indent=4,
            separators=(',',': ')))

def dump_file(data, file):
    with open(file, 'w') as out:
        json.dump(data, out, sort_keys=True, indent=4, separators=(',',': '))

def friday_of(dt):
    return dt + datetime.timedelta(days=(4 - dt.weekday()))

def sunday_of(dt):
    return dt + datetime.timedelta(days=(6 - dt.weekday()))

def get_delta(timepoint):
    tests = [ lambda x: int(timepoint),
              lambda x: (sunday_of(datetime.datetime.now()) - datetime.datetime.strptime(timepoint, "%Y-%m-%d")).days / 7 ]
    for t in tests:
        try:
            result = t(args)
            return result
        except ValueError:
            pass

    raise Exception("Value should be either a date or a number of weeks")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Retrieve data from toggl')
    parser.add_argument('--start', type=str, help='Start point to sync from, either number of weeks back or a date')
    parser.add_argument('--end', type=str, help='End point of sync interval', default=0)

    args = parser.parse_args()

    try:
        os.stat('json')
    except:
        os.mkdir('json')

    start = get_delta(args.start)
    end   = get_delta(args.end)

    now = datetime.datetime.now(TZ())

    for delta in range(end, start+1):
        check_time = now - datetime.timedelta(days=7*delta)
        friday = friday_of(check_time).strftime("%Y-%m-%d")

        outfile = 'json/info_{}.json'.format(friday)

        if isfile(outfile):
            print("We already have checked {}, skipping".format(friday))
            continue

        print("Processing {}".format(friday))

        hours = check_week_of(check_time)
        sum = 0
        for entry in hours.values():
            sum += entry['duration']
        info = {
            "week": friday,
            "sum": sum,
            "work": hours,
        }
        dump_file(info, outfile)
