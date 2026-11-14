"""Reuse actual successful verify/build, never reclassify failed native jobs."""
import hashlib,json,os,pathlib,subprocess
REPO='luxhypnomaster/sulfi-hypnotherapy';SOURCE='fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568';RUN=43548636228
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
expected={'master':(193822221,'2bb394232b631d0b6498b9b6ef6e7846a2be60b1be914b287d6bcf35593f35eb'),'client':(193822253,'8e3ddaa19a37fbc5ab66474800ae4d6f3ec5ae937eb08909a4c8bd08831fdd46')}
for e,(size,digest) in expected.items():
    f=root/(e+'27.apk');assert f.stat().st_size==size and hashlib.file_digest(f.open('rb'),'sha256').hexdigest()==digest
print('REUSE_ONLY_VERIFIED469_AND_BUILT_PAIR_PASS; no native acceptance inferred; no build/sign/OAuth/deploy')
