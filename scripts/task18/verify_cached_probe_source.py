"""Strict source/recipe gate for known cached test APKs, independent of OS image."""
import base64,json,os,pathlib,subprocess
REPO='luxhypnomaster/sulfi-hypnotherapy';KNOWN='de408f1cae08fce16069a701d147a0b1064053ba'
assert os.environ['GITHUB_REPOSITORY']==REPO and os.environ['GITHUB_REF']=='refs/heads/feat/task18-native-background-transfer'
v=json.loads((pathlib.Path(os.environ['RUNNER_TEMP'])/'task18-probe-apks/PROBE_MANIFEST_18.json').read_text());source=v['appSource'];current=os.environ['GITHUB_SHA']
assert source in [KNOWN,current],'UNREVIEWED_CACHED_FIXTURE_SOURCE'
def api(path):return json.loads(subprocess.check_output(['gh','api','repos/'+REPO+'/'+path],text=True))
def tree(sha):
 r=api('git/trees/'+sha+'?recursive=1');assert r.get('truncated') is False,'INCOMPLETE_INPUT_TREE'
 return {v['path']:v['sha'] for v in r['tree'] if v['type']=='blob'}
a,b=tree(source),tree(current)
prefixes=('lib/','test_driver/','android/','third_party/','assets/','.github/actions/setup-flutter/')
paths=[k for k in set(a)|set(b) if k.startswith(prefixes) or k in ['pubspec.yaml','pubspec.lock']]
assert all(a.get(k)==b.get(k) for k in paths),'CACHED_APK_INPUT_CHANGED_STOP_REBUILD_AND_NEW_TEST_REQUIRED'
p='.github/workflows/checks.yml'
old=base64.b64decode(api('git/blobs/'+a[p])['content']).decode();new=pathlib.Path(p).read_text()
def recipe(s):
 marker='      - name: Build disposable testOnly packages, NEVER user candidates or existing signing'
 return s.split(marker,1)[1].split('        run: |\n',1)[1].split('\n      - ',1)[0].rstrip()
assert recipe(old)==recipe(new),'CACHED_APK_BUILD_RECIPE_CHANGED_STOP'
print('CACHED_PROBE_INPUTS='+json.dumps({'source':source,'driver':current,'status':'PASS_EXACT_APK_INPUTS_AND_RECIPE','systemImageChange':'ANDROID_FRAMEWORK_QA_ONLY_NOT_GOOGLE_QA'}))
