"""Read-only proof before delivery; no build/sign/cloud actions in this gate."""
import json
import os
import pathlib
import re
import subprocess

REPO='luxhypnomaster/sulfi-hypnotherapy'
SOURCE='fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568'
RUN=43548636228
assert os.environ['GITHUB_REF']=='refs/heads/fix/task17-stable-auth-queue'
assert os.environ['GITHUB_EVENT_NAME']=='workflow_dispatch' and os.environ['GITHUB_REPOSITORY']==REPO

def gh(path):
    return json.loads(subprocess.check_output(['gh','api','repos/'+REPO+('/'+path if path else '')]))
assert gh('')['private'] is True
run=gh('actions/runs/'+str(RUN))
assert run['head_sha']==SOURCE and run['status']=='completed'
assert run['head_branch']=='fix/task17-stable-auth-queue' and run['event']=='workflow_dispatch'
jobs=gh('actions/runs/'+str(RUN)+'/jobs?per_page=100')['jobs']
for name in ['verify','candidate17']:
    matches=[j for j in jobs if j['name']==name]
    assert len(matches)==1 and matches[0]['conclusion']=='success', name
# Aggregate exact successful lanes; failed historical lanes remain failed.
# All three runs must be complete, trusted manual runs with pinned driver SHA.
lanes={}
proofs=[(RUN,SOURCE,132310281448,'native17','client',25),
        (43583577375,'56a9b362718f48bef83eca8daf24d3e58a0431ca',132413251139,'native17_cached','master',25),
        (43586282741,'fb108fb8e775dda4aa266840e8d6f67145cfb1b5',132421357694,'native17_cached','master',26)]
for rid,driver,jid,prefix,edition,baseline in proofs:
    rr=gh('actions/runs/'+str(rid))
    assert rr['head_sha']==driver and rr['status']=='completed'
    assert rr['event']=='workflow_dispatch' and rr['head_branch']=='fix/task17-stable-auth-queue'
    jj=gh('actions/runs/'+str(rid)+'/jobs?per_page=100')['jobs']
    matches=[x for x in jj if x.get('id')==jid];assert len(matches)==1
    job=matches[0]
    assert job['name'].startswith(f'{prefix} ({edition}, {baseline},') and job['conclusion']=='success'
    step=next(x for x in job['steps'] if x['name']=='UI-created native baseline to27 and cold data verification')
    assert step['conclusion']=='success'
    lanes[(edition,baseline)]=jid
assert set(lanes)=={('master',25),('master',26),('client',25)}

def tree(sha):
    t=gh('git/commits/'+sha)['tree']['sha']
    return {v['path']:v['sha'] for v in gh('git/trees/'+t)['tree']}
a=tree(SOURCE)
for driver in {x[1] for x in proofs}|{os.environ['GITHUB_SHA']}:
    b=tree(driver)
    for path in ['lib','android','third_party','test','server','pubspec.yaml','pubspec.lock']:
        assert a[path]==b[path], 'UNTESTED_RUNTIME_TREE:'+path
release_id=os.environ['TASK17_RELEASE_ID'];assert re.fullmatch(r'[0-9]{1,20}',release_id)
release=gh('releases/'+release_id)
assert release['draft'] is True and release['tag_name']=='task17-qa-pair-27' and release['target_commitish']==SOURCE
assert release['assets']==[], 'NO_OVERWRITE_EXISTING_ASSETS'
pair=json.loads((pathlib.Path(os.environ['RUNNER_TEMP'])/'task17-apks/APK_PAIR_17.json').read_text())
assert pair['source']==SOURCE and pair['ownerQA']=='NOT_RUN'
print('TASK17_PRIVATE_DELIVERY_GATE_PASS; source='+SOURCE+'; native3PASS; physicalGoogleNOT_RUN; no build/sign/deploy')
