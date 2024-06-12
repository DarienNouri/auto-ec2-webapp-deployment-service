import json
import sys
import os 

branch = sys.argv[1]
port = int(sys.argv[2])
deployed_apps_json = sys.argv[3]

with open(deployed_apps_json, 'r+') as f:
    data = json.load(f)
    branches = data.get('branches', [])
    for b in branches:
        if b['name'] == branch:
            b['port'] = port
            break
    else:
        branches.append({'name': branch, 'port': port})
        print(f'Added {branch} - {port} to deployed apps')
    data['branches'] = branches
    f.seek(0)
    json.dump(data, f, indent=4)
    f.truncate()