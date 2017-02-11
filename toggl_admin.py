#!/usr/bin/env python
import json
import requests
import urllib.parse
import base64
import sys
import datetime
from os.path import isfile

toggl_username = json.load(open('config.json'))['secrets']['toggl']

class TZ(datetime.tzinfo):
    def utcoffset(self, dt): return datetime.timedelta(hours=0)
    def dst(self,dt): return datetime.timedelta(hours=0)

def get_response(url, method="GET", params=None, data=None, headers={'content-type' : 'application/json'}):
    password="api_token"
    auth = requests.auth.HTTPBasicAuth(toggl_username, password)

    try:
        if method == "GET":
            r = requests.get(url, auth=auth, params=params, data=data, headers=headers)
        elif method == "POST":
            r = requests.post(url, auth=auth, params=params, data=data, headers=headers)
        elif method == "PUT":
            r = requests.put(url, auth=auth, params=params, data=json.dumps(data), headers=headers)
        else:
            raise NotImplementedError('HTTP method "{}" not implemented.'.format(method))
        r.raise_for_status()
    except Exception as e:
        print("OOps, something went wrong")
        print(e)
        sys.exit(1)

    return r.json()

client_infos = {}
def get_client_info(cid):
    if cid not in client_infos:
        url = "https://www.toggl.com/api/v8/clients/%s" % cid
        data = get_response(url)
        client_infos[cid] = data['data']

    return client_infos[cid]

project_infos = {}
def get_project_info(pid):
    if pid not in project_infos:
        url = "https://www.toggl.com/api/v8/projects/%s" % pid
        data = get_response(url)
        data = data['data']
        if 'cid' in data:
            client = get_client_info(data['cid'])
            data['client'] = client
        else:
            data['client'] = ''
        project_infos[pid] = data

    return project_infos[pid]

def check_week_of(day):
    monday = day - datetime.timedelta(
                days=day.weekday(),
                microseconds=day.microsecond,
                hours=day.hour)
    friday = monday + datetime.timedelta(days = 6)

    url = "https://www.toggl.com/api/v8/time_entries"
    params = {
            "start_date": monday.isoformat(),
            "end_date": friday.isoformat(),
            }

    data = get_response(url, params=params)
    return data

def get_stuff():
    return get_response("https://www.toggl.com/api/v8/me?with_related_data=true")

def dump(data):
    print((json.dumps(data, sort_keys=True, indent=4,
            separators=(',',': '))))

def dump_file(data, file):
    with open(file, 'w') as out:
        json.dump(data, out, sort_keys=True, indent=4, separators=(',',': '))

def load_file(file):
    with open(file, 'r') as f:
        return json.load(f)

def friday_of(dt):
    return dt + datetime.timedelta(days=(4 - dt.weekday()))

def fix_admin():
    now = datetime.datetime.now(TZ())
    for delta in range(8,52):
        check_time = now - datetime.timedelta(days=7*delta)
        print("Checking {} {}".format(delta, check_time.strftime("%Y-%m-%d")))

        data = check_week_of(check_time)

        for d in data:
            if not 'pid' in d:
                print("Can't find pid for {}".format(d['id']))
                dump(d)
                continue
            proj_info = get_project_info( d['pid'] )

            cname = ""
            cid   = ""
            if 'cid' in proj_info:
                cname = proj_info['client']['name']
                cid   = proj_info['client']['id']

            print("    {:8} {:20.20} {:>15.15}:{} {:>15.15}:{}".format(
                d['id'], d['description'],
                proj_info['name'], proj_info['id'],
                cname, cid ))

            # PID:31466296
            desc = d['description']
            if not 'cid' in proj_info and ( desc == 'Admin' or desc == 'Email'):
                data = { "time_entry": { "pid":31466296 }}
                url="https://www.toggl.com/api/v8/time_entries/{}".format(d["id"])
                r = get_response(url, method="PUT", data=data)

if __name__ == '__main__':
    data = get_stuff()
    data = data['data']

    projects = data['projects']
    clients  = data['clients']

    print("Projects without client")
    plookup = {}
    for p in projects:
        if 'cid' in p:
            cid = p['cid']
            if cid not in plookup:
                plookup[cid] = []
            plookup[cid].append(p)
        elif p['active']:
            print("    {} ({})".format(p['name'], p['id']))
        else:
            print("      ({})".format(p['name']))

    print("\n\n---\n")

    for c in clients:
        print("{} {}".format(c['name'],c['id']))
        cid = c['id']
        if cid in plookup:
            for p in plookup[cid]:
                print("    {}".format(p['name']))

