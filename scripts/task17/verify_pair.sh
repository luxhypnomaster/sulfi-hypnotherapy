#!/usr/bin/env bash
set -euo pipefail
pair_root="$RUNNER_TEMP/task17-apks"
pair_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
for pair_edition in master client; do
  "$pair_tools/apksigner" verify --print-certs "$pair_root/${pair_edition}27.apk" > "$pair_root/$pair_edition-cert.txt"
  grep -q '0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6' "$pair_root/$pair_edition-cert.txt"
  "$pair_tools/aapt" dump badging "$pair_root/${pair_edition}27.apk" > "$pair_root/$pair_edition-badging.txt"
done
python3 - <<'PY'
import os,pathlib,re,json,hashlib,zipfile
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task17-apks';out=[]
for edition,suffix in [('master',''),('client','.clienttest')]:
 file=root/f'{edition}27.apk';badging=(root/f'{edition}-badging.txt').read_text()
 package='ru.sulfi.sulfi_hypnotherapy'+suffix
 assert f"name='{package}'" in badging and "versionCode='27'" in badging and "versionName='0.4.19'" in badging
 with zipfile.ZipFile(file) as z:
  kernel=z.read('assets/flutter_assets/kernel_blob.bin')
  for public in [os.environ.get('ALCHEMIST_API','https://script.google.com/macros/s/AKfycbzw36cEXSHVgfRxSl7k-6c2yV4uyPapqb-zndib8AlbHxhFCstXqxoqvqTMJvlHTT5zEg/exec'),os.environ.get('GOOGLE_WEB_CLIENT_ID','325102995568-07pk1fcqvfnkp27kkmv7ple39enin31d.apps.googleusercontent.com')]:
   assert public.encode() in kernel, 'COMPILED_CONFIG_MISSING'
  assert any(b'SULFI_STORAGE_CORRUPT_NO_RESET' in z.read(n) for n in z.namelist() if n.endswith('.dex')), 'STORAGE_GUARD_MISSING'

 out.append({'edition':edition,'package':package,'versionCode':27,'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'certificateSHA256':'0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6'})
value={'source':os.environ['GITHUB_SHA'],'pair':out,'ownerQA':'NOT_RUN','liveGAS':'EXISTING6_NO_DEPLOY'}
receipt=root/'APK_PAIR_17.json'
if receipt.exists():
 assert json.loads(receipt.read_text())==value, 'CACHE_PROVENANCE_OR_BYTES_MISMATCH'
else: receipt.write_text(json.dumps(value,indent=2)+'\n')
print('APK_PAIR_17='+json.dumps(value))
PY
