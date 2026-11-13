"""Read-only gate before uploading the already-built pair to an existing PRIVATE draft."""
import json
import os
import pathlib
import re
import subprocess

REPO='luxhypnomaster/sulfi-hypnotherapy'
SOURCE='85ff50736c6be28bda55cf759f232d8347f3ad3e'
RUN=43515852713
assert os.environ['GITHUB_REF']=='refs/heads/fix/task17-stable-auth-queue'
assert os.environ['GITHUB_EVENT_NAME']=='workflow_dispatch' and os.environ['GITHUB_REPOSITORY']==REPO

def gh(path):
    return json.loads(subprocess.check_output(['gh','api','repos/'+REPO+'/'+path]))
repo=gh('');assert repo['private'] is True
run=gh('actions/runs/'+str(RUN))
assert run['head_sha']==SOURCE and run['status']=='completed' and run['conclusion']=='success'
assert run['head_branch']=='fix/task17-stable-auth-queue' and run['event']=='workflow_dispatch'
jobs=gh('actions/runs/'+str(RUN)+'/jobs?per_page=100')['jobs']
for name in ['verify','candidate17']:
    matches=[j for j in jobs if j['name']==name]
    assert len(matches)==1 and matches[0]['conclusion']=='success', name
lanes={}
for j in jobs:
    match=re.match(r'^native17 \((master|client), (25|26),',j['name'])
    if match:
        key=(match[1],int(match[2]));assert key not in lanes
        native=next(s for s in j['steps'] if s['name']=='UI-created native baseline to27 and cold data verification')
        assert native['conclusion']=='success' and j['conclusion']=='success', key
        lanes[key]=j['id']
assert set(lanes)=={('master',25),('master',26),('client',25)}

def trees(sha):
    tree=gh('git/commits/'+sha)['tree']['sha']
    return {v['path']:v['sha'] for v in gh('git/trees/'+tree)['tree']}
original,now=trees(SOURCE),trees(os.environ['GITHUB_SHA'])
for path in ['lib','android','third_party','test','server','pubspec.yaml','pubspec.lock']:
    assert original[path]==now[path], 'UNTESTED_RUNTIME_TREE:'+path
release_id=os.environ['TASK17_RELEASE_ID'];assert re.fullmatch(r'[0-9]{1,20}',release_id)
release=gh('releases/'+release_id)
assert release['draft'] is True and release['tag_name']=='task17-qa-pair-27' and release['target_commitish']==SOURCE
assert release['assets']==[], 'NO_OVERWRITE_EXISTING_ASSETS'
pair=json.loads((pathlib.Path(os.environ['RUNNER_TEMP'])/'task17-apks/APK_PAIR_17.json').read_text())
assert pair['source']==SOURCE and pair['ownerQA']=='NOT_RUN'
print('TASK17_PRIVATE_DELIVERY_GATE_PASS; source='+SOURCE+'; native3PASS; physicalGoogleNOT_RUN; no build/sign/deploy')
