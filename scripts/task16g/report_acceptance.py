"""Preserve every16G criterion; keep controlled evidence separate from owner QA."""
import collections
import csv
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
reports = root / 'reports/task16g'
native_path = reports / 'NATIVE_UI_UPGRADE_16G.json'
native = json.loads(native_path.read_text()) if native_path.exists() else {}
cases = {x['case']: x for x in native.get('cases', [])}
upgrade = all(cases.get(name, {}).get('status') == 'PASS' for name in (
    'before25_inventory', 'native_update25_to26', 'ui_after26', 'cold_restart26'))
companion = cases.get('client26_program_labels', {}).get('status') == 'PASS'
fault_path = reports / 'FAULT_APP_16G.json'
fault = json.loads(fault_path.read_text()) if fault_path.exists() else {}
fault_cases = fault.get('cases', [])
fault_pass = len(fault_cases) == 3 and all(x.get('status') == 'PASS' for x in fault_cases)
ci_path = reports / 'CI_16G.json'
ci = json.loads(ci_path.read_text()) if ci_path.exists() else {}
full = any(x['name'] == 'verify' and x['conclusion'] == 'success'
           for x in ci.get('jobs', []))
prior_path = reports / 'REGRESSION_CI_16G.json'
if not full and prior_path.exists():
    prior = json.loads(prior_path.read_text())
    validated = any(x['name'] == 'verify' and x['conclusion'] == 'success'
                    for x in prior.get('jobs', []))
    unchanged = subprocess.run(
        ['git', 'diff', '--quiet', prior['headSha'], '--', 'lib', 'android',
         'third_party', 'test', 'server', 'pubspec.yaml', 'pubspec.lock'],
        cwd=root, check=False).returncode == 0
    full = validated and unchanged

pair = reports / 'APK_READBACK_16G.json'
pair_verified = pair.exists() and json.loads(pair.read_text()).get('allVerified') is True
delivery = reports / 'DRIVE_READBACK_16G.json'
delivered = delivery.exists() and json.loads(delivery.read_text()).get('allVerified') is True

# outcome, code, emulator, evidence+remaining. LIVE/Owner default NOT_RUN.
rows = {
    'G0-01': ('PASS', 'PASS', 'NOT_RUN', 'BASELINE_16G.md; PR45/46 exact ancestry/diff'),
    'G0-02': ('PASS', 'PASS', 'NOT_RUN', 'BOUNDARIES_16G.json; stable main/PR45/46/assets/signing; no GAS/ACL mutations'),
    'G0-03': ('PASS', 'PASS', 'NOT_RUN', 'Owner13.11 scope/README; old objects recovery explicitly excluded; phone root cause UNKNOWN retained'),
    'G0-04': ('PASS', 'PASS', 'NOT_RUN', 'BASELINE_16G.md; existing identity/queue/catalog kept, narrow pinned SQLite callback patch'),
    'DAT-01': ('PASS', 'PASS', 'PASS', 'NATIVE_STORAGE_16G.json; exact production callback RW/RO corruption SHA unchanged, run43347643988'),
    'DAT-02': ('PASS', 'PASS', 'PASS' if fault_pass else 'PARTIAL', 'G1 negative11 + retained media; FAULT_APP_16G.json actual app corrupt/missing-db only if PASS; owner data never touched'),
    'DAT-03': ('PASS' if upgrade else 'BLOCKED', 'PASS', 'PASS' if upgrade else 'BLOCKED', 'NATIVE_UI_UPGRADE_16G.json; UI-created MASTER25→26 graph/history/current; physical owner NOT_RUN'),
    'DAT-04': ('PASS' if upgrade else 'PARTIAL', 'PASS', 'PASS' if upgrade else 'BLOCKED', 'Native before/after/cold SHA;3distinct wave bytes,2same display titles/distinct IDs; fixture rows not SQL seeded'),
    'DAT-05': ('PASS', 'PASS', 'NOT_RUN', 'PR46 legacy scope RED/GREEN retained; same server-verified subject domain test; real Google UI NOT_RUN'),
    'DAT-06': ('PASS', 'PASS', 'NOT_RUN', 'Legacy alias deny other subjects/CLIENT/guest; actual2Google users still owner QA'),
    'DAT-07': ('PARTIAL', 'PASS', 'PARTIAL', 'Dart preflight11 incl WAL/hot journal; native exact callback + FAULT_APP_16G.json; full Android WAL/hot-journal interruption matrix and physical hardware NOT_RUN'),
    'DAT-08': ('PASS', 'PASS', 'PASS' if upgrade else 'NOT_RUN', 'Schema9, no DDL/table/ID/template rewrite; marker auxiliary file only; SCOPE_VERIFY_16G.json'),
    'AUTH-01': ('PARTIAL', 'PASS', 'NOT_RUN', 'Existing shared DiaryController/SDK in profile+shield, role/widget tests; real Google both entrypoints NOT_RUN'),
    'AUTH-02': ('PARTIAL', 'PASS', 'NOT_RUN', 'Clock/refresh singleflight/offline is not logout tests PASS; actual SDK restore after phone restart NOT_RUN'),
    'AUTH-03': ('PARTIAL', 'PASS', 'NOT_RUN', '401/403/DNS/abort bounded retries/sanitized errors domain PASS; actual radios/provider unavailable'),
    'PUB-01': ('PARTIAL', 'PASS', 'NOT_RUN', 'Production Dart→JS controlled authoritative module3tracks commit PASS; live owner→GAS6→Drive NOT_RUN'),
    'PUB-02': ('PARTIAL', 'PASS', 'NOT_RUN', 'Extended16G program exact graph publication/CLIENT install PASS controlled; real server Google NOT_RUN'),
    'PUB-03': ('PARTIAL', 'PASS', 'NOT_RUN', 'Controlled diary publish/text update exact ContentLink revision PASS; live NOT_RUN'),
    'PUB-04': ('PARTIAL', 'PASS', 'NOT_RUN', 'Controlled uploaded byte counter unchanged for program/diary text edits and committed audio/cover; live NOT_RUN'),
    'PUB-05': ('PARTIAL', 'PASS', 'NOT_RUN', 'DNS/abort/retry/receipt/idempotence/account-bound queue tests; local originals retained; physical network switch NOT_RUN'),
    'PUB-06': ('PARTIAL', 'PASS', 'PARTIAL' if companion else 'NOT_RUN', 'CLIENT deny+selective program3track install controlled; native labels separate package; Google/live/physical heard sound NOT_RUN'),
    'PUB-07': ('PASS', 'PASS', 'NOT_RUN', 'Existing GAS6 endpoints kept/server source unchanged; no deploy.16B server candidate NEEDS_OWNER_GAS_DEPLOY_APPROVAL'),
    'UI-01': ('PASS', 'PASS', 'PASS' if companion else 'NOT_RUN', '18label files + MASTER/CLIENT widget/small-screen tests; no static Russian template labels in lib'),
    'UI-02': ('PASS', 'PASS', 'NOT_RUN', 'Internal ContentType.template/session_templates/ID/wire/ContentLink/capsule unchanged; SCOPE_VERIFY_16G.json'),
    'UI-03': ('PASS', 'PASS', 'NOT_RUN', 'Legacy custom name+IDs/digest/plan+module3tracks capsule roundtrip; no user naming rewrite'),
    'UI-04': ('PASS', 'PASS', 'NOT_RUN', 'Only terms/storage/stabilization; no course/questionnaire/new artwork; K034/K036 future backlog'),
    'REL-01': ('PASS' if full else 'BLOCKED', 'PASS' if full else 'BLOCKED', 'NOT_RUN', 'REGRESSION_CI_16G.json verify43350711471 SUCCESS source1190989; actual remote reuse gate + identical seven app/test/server trees; latest native job separate'),
    'REL-02': ('PARTIAL' if upgrade else 'BLOCKED', 'PASS', 'PASS' if upgrade else 'BLOCKED', 'Controlled MASTER25→candidate native inventory/audio only; physical owner+CLIENT25 update and real offline hearing NOT_RUN'),
    'REL-03': ('PASS', 'PASS', 'PASS' if upgrade else 'BLOCKED', 'Workflow withholds pair unless full checks and populated upgrade/CLIENT smoke PASS; owner approval still needed to install'),
    'REL-04': ('PASS' if pair_verified else 'BLOCKED', 'PASS', 'PASS' if pair_verified else 'NOT_RUN', 'BUILD_ATTEMPTS_16G.json identical signed binaries internally built/cert checked; APK_READBACK_16G.json only after accepted gates; otherwise NO issued APK'),
    'REL-05': ('PASS', 'PASS', 'NOT_RUN', 'RESULT_16G/OWNER_PHONE_QA_16G distinguish controlled PASS from real Google/Drive/physical NOT_RUN'),
    'REL-06': ('PASS' if delivered else 'PARTIAL', 'PASS', 'NOT_RUN', 'DRIVE_READBACK_16G.json;7required reports in existing16folder; no overwrite16B/16V'),
    'EFF-01': ('PASS', 'PASS', 'NOT_RUN', 'CODEX_EFFICIENCY_16G.md lists actual runs/cancellation/failures/durations; owner quota UNKNOWN, no invented percentages'),
}
with (root / 'docs/task16g/ACCEPTANCE_16G.csv').open(newline='') as f:
    matrix = list(csv.DictReader(f))
assert len(matrix) == 33 and set(rows) == {r['ID'] for r in matrix}
for row in matrix:
    outcome, code, emulator, evidence = rows[row['ID']]
    row.update({'Код': code, 'Эмулятор': emulator, 'LIVE': 'NOT_RUN',
                'Владелец': 'NOT_RUN', 'Итог': outcome, 'Ссылка/примечания': evidence})
    if row['ID'] == 'G0-03':
        row['Владелец'] = 'PASS'  # Explicit task scope decision, not phone QA.
with (reports / 'ACCEPTANCE_16G.csv').open('w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=matrix[0].keys(), lineterminator='\n')
    writer.writeheader()
    writer.writerows(matrix)
counts = dict(collections.Counter(r['Итог'] for r in matrix))
result = {'criteria': 33, 'counts': counts, 'controlledUpgrade': upgrade,
          'fullCI': full, 'actualAppFaultChecks': fault_pass, 'pairReadbackVerified': bool(pair_verified),
          'ownerGoogleDrivePhysicalQA': 'NOT_RUN',
          'status': 'CONTROLLED_CANDIDATE_OWNER_QA_PENDING' if pair_verified else 'BLOCKED_CANDIDATE_WITHHELD'}
(reports / 'ACCEPTANCE_SUMMARY_16G.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
