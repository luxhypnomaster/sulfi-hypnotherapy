"""Cache only disposable fixtures; verify provenance/bytes/package before ADB."""
import hashlib,json,os,pathlib,re,subprocess,sys
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task18-probe-apks'
manifest=root/'PROBE_MANIFEST_18.json'
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
if sys.argv[1]=='create':
 value={'appSource':os.environ['GITHUB_SHA'],'target':'test_driver/transfer_probe.dart','testOnly':True,
  'files':{e:{'sha256':sha(root/(e+'.apk')),'bytes':(root/(e+'.apk')).stat().st_size} for e in ['master','client']}}
 manifest.write_text(json.dumps(value,indent=2)+'\n')
else:
 value=json.loads(manifest.read_text());assert re.fullmatch(r'[a-f0-9]{40}',value['appSource'])
 assert value['target']=='test_driver/transfer_probe.dart' and value['testOnly'] is True
 tools=sorted((pathlib.Path(os.environ['ANDROID_HOME'])/'build-tools').glob('*/aapt'))[-1].parent
 for e in ['master','client']:
  file=root/(e+'.apk');assert sha(file)==value['files'][e]['sha256'] and file.stat().st_size==value['files'][e]['bytes']
  package='ru.sulfi.sulfi_hypnotherapy'+('.clienttest' if e=='client' else '')+'.transferprobe'
  badge=subprocess.check_output([str(tools/'aapt'),'dump','badging',str(file)],text=True)
  assert "name='"+package+"'" in badge,'WRONG_PACKAGE_NO_ADB_INSTALL'
  xml=subprocess.check_output([str(tools/'aapt'),'dump','xmltree',str(file),'AndroidManifest.xml'],text=True)
  assert any('testOnly' in l and '0xffffffff' in l for l in xml.splitlines()),'NOT_DISPOSABLE_TEST_ONLY'
  cert=subprocess.check_output([str(tools/'apksigner'),'verify','--print-certs',str(file)],text=True)
  assert '0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6' not in cert,'UNEXPECTED_USER_SIGNING_KEY_IN_FIXTURE'
 with open(os.environ['GITHUB_ENV'],'a') as f:f.write('TASK18_PROBE_APP_SOURCE='+value['appSource']+'\n')
 print('DISPOSABLE_PROBE_PROVENANCE='+json.dumps(value))
