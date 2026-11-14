"""Reuse actual successful verify/build, never reclassify failed native jobs."""
import hashlib,json,os,pathlib,subprocess
REPO='luxhypnomaster/sulfi-hypnotherapy';SOURCE='85ff50736c6be28bda55cf759f232d8347f3ad3e';RUN=43515852713
assert os.environ['GITHUB_EVENT_NAME']=='workflow_dispatch' and os.environ['GITHUB_REF']=='refs/heads/fix/task17-stable-auth-queue' and os.environ['GITHUB_REPOSITORY']==REPO

def gh(path):return json.loads(subprocess.check_output(['gh','api','repos/'+REPO+('/'+path if path else '')]))
assert gh('')['private'] is True
run=gh('actions/runs/'+str(RUN));assert run['head_sha']==SOURCE and run['event']=='workflow_dispatch'
jobs=gh('actions/runs/'+str(RUN)+'/jobs?per_page=100')['jobs']
for name in ['verify','candidate17']:
    j=next(j for j in jobs if j['name']==name);assert j['conclusion']=='success',name
assert next(s for s in next(j for j in jobs if j['name']=='candidate17')['steps'] if s['name']=='Quarantine only, no APK delivery before native safety gates')['conclusion']=='success'
def tree(sha):return {v['path']:v['sha'] for v in gh('git/trees/'+gh('git/commits/'+sha)['tree']['sha'])['tree']}
a,b=tree(SOURCE),tree(os.environ['GITHUB_SHA'])
for path in ['lib','android','third_party','test','server','pubspec.yaml','pubspec.lock']:assert a[path]==b[path], 'UNTESTED_RUNTIME:'+path
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task17-apks';pair=json.loads((root/'APK_PAIR_17.json').read_text());assert pair['source']==SOURCE and pair['ownerQA']=='NOT_RUN'
expected={'master':(193822185,'f065c45d269b800cdcfc967c0c5b7f3e06b4355c9e15ff45bdfd02da0243c9c6'),'client':(193822221,'a2f4cdef7869ae1b57ba6337bf550997ee36c3acacddadab33a14f75c513071e')}
for e,(size,digest) in expected.items():
    f=root/(e+'27.apk');assert f.stat().st_size==size and hashlib.file_digest(f.open('rb'),'sha256').hexdigest()==digest
print('REUSE_ONLY_VERIFIED468_AND_BUILT_PAIR_PASS; no native acceptance inferred; no build/sign/OAuth/deploy')
