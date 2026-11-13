#!/usr/bin/env bash
set -euo pipefail
python3 scripts/task16g/reuse_verify.py
python3 scripts/task16g/verify_delivery.py
python3 - <<'PY'
import pathlib,os,json,hashlib
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task16g-apks'
pair=json.loads((root/'APK_PAIR_16G.json').read_text())
expected=next(x for x in json.loads(pathlib.Path('reports/task16g/BUILD_ATTEMPTS_16G.json').read_text())['pairs'] if x['source']=='9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c')
assert pair==expected
for item in pair['pair']:
 f=root/(item['edition']+'26.apk')
 assert f.stat().st_size==item['bytes']
 assert hashlib.sha256(f.read_bytes()).hexdigest()==item['sha256']
print('CACHED_PAIR_SHA_AND_PRODUCER_PASS; no build or signing')
PY
pair_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"
for pair_edition in master client; do
  "$pair_tools/apksigner" verify --print-certs "$RUNNER_TEMP/task16g-apks/${pair_edition}26.apk" > "$RUNNER_TEMP/task16g-${pair_edition}-public-cert.txt"
  grep -q '0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6' "$RUNNER_TEMP/task16g-${pair_edition}-public-cert.txt"
done
gh release upload task16g-qa-pair-26 "$RUNNER_TEMP/task16g-apks/master26.apk" "$RUNNER_TEMP/task16g-apks/client26.apk" "$RUNNER_TEMP/task16g-apks/APK_PAIR_16G.json" --repo luxhypnomaster/sulfi-hypnotherapy
gh api repos/luxhypnomaster/sulfi-hypnotherapy/releases/444069048 --jq '{id,draft,tag_name,target_commitish,html_url,assets:[.assets[]|{id,name,size,digest,browser_download_url}]}'
