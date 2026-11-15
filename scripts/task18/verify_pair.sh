#!/usr/bin/env bash
set -euo pipefail
pair_root="$RUNNER_TEMP/task18-apks"
pair_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
for pair_edition in master client; do
  "$pair_tools/apksigner" verify --print-certs "$pair_root/${pair_edition}28.apk" > "$pair_root/$pair_edition-cert.txt"
  grep -q '0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6' "$pair_root/$pair_edition-cert.txt"
  "$pair_tools/aapt" dump badging "$pair_root/${pair_edition}28.apk" > "$pair_root/$pair_edition-badging.txt"
  "$pair_tools/aapt" dump xmltree "$pair_root/${pair_edition}28.apk" AndroidManifest.xml > "$pair_root/$pair_edition-manifest.txt"
done
python3 - <<'PY'
import os,pathlib,re,json,hashlib,zipfile
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task18-apks';out=[]
for edition,suffix in [('master',''),('client','.clienttest')]:
 file=root/f'{edition}28.apk';badging=(root/f'{edition}-badging.txt').read_text()
 package='ru.sulfi.sulfi_hypnotherapy'+suffix
 assert f"name='{package}'" in badging and "versionCode='28'" in badging and "versionName='0.4.20'" in badging
 with zipfile.ZipFile(file) as z:
  kernel=z.read('assets/flutter_assets/kernel_blob.bin')
  for public in [os.environ.get('ALCHEMIST_API','https://script.google.com/macros/s/AKfycbzw36cEXSHVgfRxSl7k-6c2yV4uyPapqb-zndib8AlbHxhFCstXqxoqvqTMJvlHTT5zEg/exec'),os.environ.get('GOOGLE_WEB_CLIENT_ID','325102995568-07pk1fcqvfnkp27kkmv7ple39enin31d.apps.googleusercontent.com')]:
   assert public.encode() in kernel, 'COMPILED_CONFIG_MISSING'
  assert b'CONTROLLED_NATIVE18_NO_GAS' not in kernel and b'CONTROLLED_OWNER_18_' not in kernel, 'PROBE_DART_IN_SHIPPING_APK'
  dex=b''.join(z.read(n) for n in z.namelist() if n.endswith('.dex'))
  assert b'Lru/sulfi/sulfi_hypnotherapy/probe/TransferProbeControl;' not in dex and b'ru.sulfi/controlled18' not in dex, 'PROBE_NATIVE_IN_SHIPPING_APK'
  assert b'Lru/sulfi/sulfi_hypnotherapy/transfer/TransferJobService;' in dex, 'NATIVE_EXECUTOR_MISSING'
  assert any(b'SULFI_STORAGE_CORRUPT_NO_RESET' in z.read(n) for n in z.namelist() if n.endswith('.dex')), 'STORAGE_GUARD_MISSING'

 manifest=(root/f'{edition}-manifest.txt').read_text()
 assert not any(('testOnly' in line or 'usesCleartextTraffic' in line) and '0xffffffff' in line for line in manifest.splitlines()), 'PROBE_DEBUG_MANIFEST_IN_SHIPPING_APK'
 for permission in ['android.permission.RUN_USER_INITIATED_JOBS','android.permission.FOREGROUND_SERVICE_DATA_SYNC','android.permission.ACCESS_NETWORK_STATE']:
  assert permission in manifest, 'TRANSFER_PERMISSION_MISSING'
 out.append({'edition':edition,'package':package,'versionCode':28,'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'certificateSHA256':'0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6'})
value={'source':os.environ.get('PAIR_SOURCE_SHA',os.environ['GITHUB_SHA']),'pair':out,'ownerQA':'NOT_RUN','safeForOwnerInstall':False,'nativeSafety':'PENDING','liveGAS':'EXISTING6_NO_DEPLOY'}
receipt=root/'QUARANTINE_PAIR_18.json'
if receipt.exists():
 assert json.loads(receipt.read_text())==value, 'CACHE_PROVENANCE_OR_BYTES_MISMATCH'
else: receipt.write_text(json.dumps(value,indent=2)+'\n')
print('QUARANTINE_PAIR_18='+json.dumps(value))
PY
