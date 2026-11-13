#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
import json,os,pathlib
folder=pathlib.Path(os.environ['RUNNER_TEMP'])
d=json.loads((folder/'task16g-evidence/NATIVE_UI_UPGRADE_16G.json').read_text())
cases={x['case']:x for x in d['cases']}
for name in ['before25_inventory','native_update25_to26','ui_after26','cold_restart26','client26_program_labels']:
 assert cases[name]['status']=='PASS',name
fault=json.loads((folder/'task16g-evidence/FAULT_APP_16G.json').read_text())
assert len(fault['cases'])==3 and all(x['status']=='PASS' for x in fault['cases'])
pair=json.loads((folder/'task16g-apks/APK_PAIR_16G.json').read_text())
assert pair['source']=='9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c'
(folder/'task16g-notes.md').write_text('Ограниченная пара кандидатов №16-Г 0.4.18+26. APK source '+pair['source']+'. App/test/server trees совпадают с полностью проверенным11909895da4f2967b77f12a8b8da98ff50b370d5. Controlled actual UI25→26/cold and app corruption/missing-db fail-closed PASS. Реальные Google/Drive/two-phone/микрофон/слышимость OWNER_QA NOT_RUN. Не production release. Установка только по отдельному решению владельца, поверх25 без удаления. GAS6/main/signing/ACL сохранены. SHA и размеры APK_PAIR_16G.json.')
PY
! gh api repos/luxhypnomaster/sulfi-hypnotherapy/releases/tags/task16g-qa-pair-26 > /dev/null 2>&1
gh release create task16g-qa-pair-26 --repo luxhypnomaster/sulfi-hypnotherapy --target 9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c --draft --title '№16-Г: кандидаты26, controlled QA пройдена, owner QA впереди' --notes-file "$RUNNER_TEMP/task16g-notes.md"
gh release upload task16g-qa-pair-26 "$RUNNER_TEMP/task16g-apks/master26.apk" "$RUNNER_TEMP/task16g-apks/client26.apk" "$RUNNER_TEMP/task16g-apks/APK_PAIR_16G.json" "$RUNNER_TEMP/task16g-evidence/NATIVE_UI_UPGRADE_16G.json" "$RUNNER_TEMP/task16g-evidence/FAULT_APP_16G.json" --repo luxhypnomaster/sulfi-hypnotherapy
