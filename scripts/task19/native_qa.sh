#!/usr/bin/env bash
set -euo pipefail
test -f .task17-sdk-ready.json
auth_root="$RUNNER_TEMP/task19-prototypes"
for auth_edition in master client; do
  auth_package=ru.sulfi.sulfi_hypnotherapy
  if [ "$auth_edition" = client ]; then auth_package="$auth_package.clienttest"; fi
  auth_package="$auth_package.auth19"
  adb install -r "$auth_root/$auth_edition.auth19.apk"
  adb install -r "$auth_root/$auth_edition.androidTest.apk"
  for auth_phase in persistAndConcurrentRotate coldRestoreAndLogout; do
    adb logcat -c
    adb shell am instrument -w -r -e class "ru.sulfi.sulfi_hypnotherapy.auth19.Auth19NativeTest#$auth_phase" \
      "$auth_package.test/androidx.test.runner.AndroidJUnitRunner" > "$auth_root/$auth_edition-$auth_phase.txt"
    cat "$auth_root/$auth_edition-$auth_phase.txt"
    grep -q 'OK (1 test)' "$auth_root/$auth_edition-$auth_phase.txt"
    adb logcat -d -s System.out:I '*:S' > "$auth_root/$auth_edition-$auth_phase-log.txt"
    adb shell am force-stop "$auth_package" # disposable .auth19 ONLY, no owner app
  done
done
python3 - <<'PY'
import hashlib,json,os,pathlib,re,subprocess
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task19-prototypes';results=[]
for e in ['master','client']:
 cases=[]
 for name in ['persistAndConcurrentRotate','coldRestoreAndLogout']:
  text=(root/(e+'-'+name+'-log.txt')).read_text()
  v=[json.loads(x) for x in re.findall(r'AUTH19_NATIVE_RECEIPT=(\{[^\n]+\})',text)]
  assert len(v)==1,'REAL_NATIVE_RECEIPT_MISSING';cases.append(v[0])
 assert cases[0]['pid']!=cases[1]['pid'],'COLD_PROCESS_NOT_PROVEN'
 assert cases[0]['refreshes']==1 and cases[0]['encrypted'] is True
 assert cases[1]['refreshes']==0 and cases[1]['logoutTombstone'] is True
 b=json.loads((root/(e+'-build.json')).read_text());assert b['package'].endswith('.auth19')
 results.append({'edition':e,'package':b['package'],'cases':cases,'status':'PASS_CONTROLLED_NATIVE_NOT_GOOGLE'})
packages=subprocess.check_output(['adb','shell','pm','list','packages','-U'],text=True)
uids=[re.search(re.escape(r['package'])+r' uid:(\d+)',packages)[1] for r in results]
assert len(set(uids))==2,'PACKAGES_SHARE_UID'
value={'source':os.environ['GITHUB_SHA'],'api':35,'backend':'CONTROLLED_NOT_SUPABASE_NETWORK','Google':'NOT_RUN',
 'ownerPhone':'NOT_RUN','newProcessesProven':True,'separateUIDs':True,'results':results}
(root/'NATIVE_AUTH19.json').write_text(json.dumps(value,indent=2)+'\n');print('AUTH19_NATIVE='+json.dumps(value))
PY
