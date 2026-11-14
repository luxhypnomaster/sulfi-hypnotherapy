"""Independent raw-download verification; not producer metadata or mock APKs."""
import hashlib,json,os,pathlib,re,subprocess,sys,zipfile
SOURCE='fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568'
CERT='0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6'
EXPECTED={'master':(193822221,'2bb394232b631d0b6498b9b6ef6e7846a2be60b1be914b287d6bcf35593f35eb','ru.sulfi.sulfi_hypnotherapy'),'client':(193822253,'8e3ddaa19a37fbc5ab66474800ae4d6f3ec5ae937eb08909a4c8bd08831fdd46','ru.sulfi.sulfi_hypnotherapy.clienttest')}
CONFIG=['https://script.google.com/macros/s/AKfycbzw36cEXSHVgfRxSl7k-6c2yV4uyPapqb-zndib8AlbHxhFCstXqxoqvqTMJvlHTT5zEg/exec','325102995568-07pk1fcqvfnkp27kkmv7ple39enin31d.apps.googleusercontent.com']

def verify(folder,sdk,jdk):
 rows=[];env={**os.environ,'JAVA_HOME':str(jdk)}
 for edition,(size,digest,package) in EXPECTED.items():
  file=folder/(edition+'27.apk');assert file.stat().st_size==size,'SIZE_MISMATCH'
  with file.open('rb') as stream:actual=hashlib.file_digest(stream,'sha256').hexdigest()
  assert actual==digest,'RAW_BYTES_NOT_VERIFIED_FBD'
  output=subprocess.check_output([str(sdk/'apksigner'),'verify','--print-certs',str(file)],env=env,text=True)
  certs=re.findall(r'Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]+)',output)
  assert [x.lower() for x in certs]==[CERT],'SIGNER_SET_MISMATCH'
  badging=subprocess.check_output([str(sdk/'aapt'),'dump','badging',str(file)],env=env,text=True)
  match=re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'",badging,re.M)
  assert match and match.groups()==(package,'27','0.4.19'),'PACKAGE_VERSION_MISMATCH'
  with zipfile.ZipFile(file) as z:
   kernel=z.read('assets/flutter_assets/kernel_blob.bin')
   assert all(v.encode() in kernel for v in CONFIG),'COMPILED_CONFIG_MISMATCH'
   assert any(b'SULFI_STORAGE_CORRUPT_NO_RESET' in z.read(n) for n in z.namelist() if n.endswith('.dex')),'STORAGE_GUARD_MISSING'
  rows.append({'edition':edition,'package':package,'versionCode':27,'versionName':'0.4.19','bytes':size,'sha256':actual,'certificateSHA256':CERT,'signatureVerified':True,'compiledConfigVerified':True,'storageGuardVerified':True})
 return {'source':SOURCE,'pair':rows,'allVerified':True,'ownerQA':'NOT_RUN','method':'raw GitHub asset download + exact bytes + independent apksigner/aapt + compiled constants/DEX guard','liveGAS':'EXISTING6_NO_DEPLOY'}
if __name__=='__main__':
 result=verify(pathlib.Path(sys.argv[1]),pathlib.Path(sys.argv[2]),pathlib.Path(sys.argv[3]));pathlib.Path(sys.argv[4]).write_text(json.dumps(result,indent=2)+'\n');print('RAW_APK_PAIR_CERT_HASH_PACKAGE_CONFIG_PASS')
