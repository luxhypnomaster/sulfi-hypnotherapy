"""Reuse only actually passed unchanged Dart/server inputs; native stays gated."""
import base64,hashlib,json,os,pathlib,subprocess
REPO='luxhypnomaster/sulfi-hypnotherapy';BASE='19c3345cd42d369fa3a0bc9a76e0f1ee55bf8c03';RUN=43704911303
assert os.environ['GITHUB_REPOSITORY']==REPO and os.environ['GITHUB_REF']=='refs/heads/feat/task18-native-background-transfer'
def api(path):return json.loads(subprocess.check_output(['gh','api','repos/'+REPO+'/'+path],text=True))
r=api('actions/runs/'+str(RUN));assert r['head_sha']==BASE and r['status']=='completed'
jobs=api('actions/runs/'+str(RUN)+'/jobs?per_page=100')['jobs'];assert any(j['name']=='verify' and j['conclusion']=='success' for j in jobs)
def tree(sha):
 value=api('git/trees/'+sha+'?recursive=1');assert value.get('truncated') is False,'INCOMPLETE_TREE_REQUIRES_FULL_VERIFY'
 return {v['path']:v['sha'] for v in value['tree'] if v['type']=='blob'}
a,b=tree(BASE),tree(os.environ['GITHUB_SHA']);changes=sorted(k for k in set(a)|set(b) if a.get(k)!=b.get(k))
allowed_prefix=('reports/task18/','docs/task18/','scripts/task18/','android/app/src/test/')
allowed_exact={'README.md','BACKLOG.md','CHANGELOG.md','.github/workflows/checks.yml',
 'android/app/src/main/kotlin/ru/sulfi/sulfi_hypnotherapy/transfer/TransferPlatform.kt',
 'android/app/src/main/kotlin/ru/sulfi/sulfi_hypnotherapy/transfer/JobOwnership.kt','android/app/build.gradle.kts'}
assert all(k in allowed_exact or k.startswith(allowed_prefix) for k in changes),'DART_OR_SERVER_INPUT_CHANGED_REQUIRES_FULL_VERIFY'
# Gradle runtime/signing configuration unchanged; the sole addition is JVM tests.
p='android/app/build.gradle.kts'
if a.get(p)!=b.get(p):
 old=base64.b64decode(api('git/blobs/'+a[p])['content']).decode()
 assert pathlib.Path(p).read_text()==old+'\ndependencies {\n    testImplementation("junit:junit:4.13.2")\n}\n','UNREVIEWED_ANDROID_CONFIG_CHANGE'
value={'source':os.environ['GITHUB_SHA'],'base':BASE,'realPassedVerifyRun':RUN,'matchedDartTestsPubspecServerAssets':True,
 'changedPaths':changes,'scope':'DART_SERVER_FORMAT_ANALYZE_CONTRACT_ONLY','nativeCompileAndInstrumentation':'REQUIRED_NEW_RUN','status':'PASS_UNCHANGED_INPUT_REUSE'}
out=pathlib.Path(os.environ['RUNNER_TEMP'])/'REUSED_DART_VERIFY_18.json';out.write_text(json.dumps(value,indent=2)+'\n')
print('REUSED_DART_VERIFY_18='+json.dumps(value));print('REUSED_DART_VERIFY_SHA256='+hashlib.sha256(out.read_bytes()).hexdigest())
