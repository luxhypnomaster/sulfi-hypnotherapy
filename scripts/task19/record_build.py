"""Only isolated packages, no stable signing key or real project/credentials."""
import hashlib,json,os,pathlib,subprocess,zipfile,xml.etree.ElementTree as E
import sys
edition=sys.argv[1];assert edition in ['master','client']
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task19-prototypes'
tools=sorted((pathlib.Path(os.environ['ANDROID_HOME'])/'build-tools').glob('*/aapt'))[-1].parent
apk=root/(edition+'.auth19.apk')
badging=subprocess.check_output([str(tools/'aapt'),'dump','badging',str(apk)],text=True)
package='ru.sulfi.sulfi_hypnotherapy'+('.clienttest' if edition=='client' else '')+'.auth19'
assert "name='"+package+"'" in badging,'NOT_ISOLATED_PACKAGE_STOP'
subprocess.run([str(tools/'apksigner'),'verify',str(apk)],check=True,capture_output=True)
with zipfile.ZipFile(apk) as z:
 dex=b''.join(z.read(p) for p in z.namelist() if p.endswith('.dex'))
 assert b'Lru/sulfi/sulfi_hypnotherapy/auth19/SecureSessionStore;' in dex,'BROKER_NOT_COMPILED'
forbidden=['SULFI_SIGNING_STORE_FILE','CLASPRC_JSON','SUPABASE_SERVICE_ROLE_KEY','SUPABASE_JWT_SECRET']
assert all(not os.environ.get(k) for k in forbidden),'PROTOTYPE_MUST_NOT_RECEIVE_PRODUCTION_SECRETS'
tests=[]
for path in pathlib.Path('build/app/test-results/testDebugUnitTest').glob('TEST-*.xml'):
 v=E.parse(path).getroot();assert int(v.get('failures','0'))==0 and int(v.get('errors','0'))==0
 tests.append({'suite':v.get('name'),'tests':int(v.get('tests','0'))})
assert any(x['suite'].endswith('.AuthCoordinatorTest') and x['tests']>=17 for x in tests),'NATIVE_JVM_TESTS_MISSING'
value={'source':os.environ['GITHUB_SHA'],'edition':edition,'package':package,'apkBytes':apk.stat().st_size,
 'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'jvm':tests,'SupabaseGoogleLive':'NOT_RUN_PROJECT_NOT_CONFIGURED',
 'ownerPhone':'NOT_RUN','productionSigning':'NOT_USED','distributeToOwner':'NO_UNCONFIGURED_PROTOTYPE','legacyData':'NOT_OPENED'}
(root/(edition+'-build.json')).write_text(json.dumps(value,indent=2)+'\n');print('AUTH19_BUILD='+json.dumps(value))
