#!/usr/bin/env bash
set -euo pipefail
pair_root="$RUNNER_TEMP/task16g-apks"
pair_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
for pair_edition in master client; do
  "$pair_tools/apksigner" verify --print-certs "$pair_root/${pair_edition}26.apk" > "$pair_root/$pair_edition-cert.txt"
  grep -q '0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6' "$pair_root/$pair_edition-cert.txt"
  "$pair_tools/aapt" dump badging "$pair_root/${pair_edition}26.apk" > "$pair_root/$pair_edition-badging.txt"
done
python3 - <<'PY'
import os,pathlib,re,json,hashlib
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task16g-apks';out=[]
for edition,suffix in [('master',''),('client','.clienttest')]:
 file=root/f'{edition}26.apk';badging=(root/f'{edition}-badging.txt').read_text()
 package='ru.sulfi.sulfi_hypnotherapy'+suffix
 assert f"name='{package}'" in badging and "versionCode='26'" in badging
 out.append({'edition':edition,'package':package,'versionCode':26,'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'certificateSHA256':'0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6'})
value={'source':os.environ['GITHUB_SHA'],'pair':out,'ownerQA':'NOT_RUN','liveGAS':'EXISTING6_NO_DEPLOY'}
(root/'APK_PAIR_16G.json').write_text(json.dumps(value,indent=2)+'\n');print('APK_PAIR_16G='+json.dumps(value))
PY
