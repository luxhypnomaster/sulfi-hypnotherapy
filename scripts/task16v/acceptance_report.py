"""Evidence-backed report assembly. No criterion is silently dropped."""
import collections,csv,json,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
reports=root/'reports/task16v'
# status, code, native, owner, evidence, remaining
states={
'INV-01':('PASS','PASS','NOT_RUN','PASS','ROOT_CAUSE_16V.md','Normal update confirmed by owner; not asked again'),
'INV-02':('PASS','PASS','NOT_RUN','NOT_RUN','ROOT_CAUSE_16V.md','Physical bytes UNKNOWN; no deletion/recovery claim'),
'INV-03':('PASS','PASS','NOT_RUN','NOT_RUN','PROGRESS.md;checks.yml STOP-SHIP','No Sulfi APK26 built; owner device untouched'),
'INV-04':('PASS','PASS','PASS','NOT_RUN','APK24_APK25_READBACK_16V.json;BINARY_METADATA_16V.json','Both real immutable APKs, native apksigner/aapt; not owner install inspection'),
'INV-05':('PARTIAL','PASS','PARTIAL','BLOCKED','DIFF_AUDIT_16V.md;native inventories','Owner actual SQLite/WAL/media paths unavailable'),
'INV-06':('PARTIAL','PASS','PARTIAL','BLOCKED','DIFF_AUDIT_16V.md;native UI evidence','Owner files unavailable; no original media writes performed'),
'INV-07':('PASS','PASS','PASS','NOT_RUN','DEPENDENCY_SAFETY_16V.md;NATIVE_UI_UPGRADE_RUN5.json','Audit found default native corruption handler risk; not fixed or proven owner cause'),
'INV-08':('PASS','PASS','PARTIAL','BLOCKED','ROOT_CAUSE_16V.md;legacy scope RED/GREEN logs','Same-owner alias proven in controlled domain test; actual Google lifecycle blocked'),
'INV-09':('PARTIAL','PASS','PARTIAL','BLOCKED','DIFF_AUDIT_16V.md','Startup audio/diary/history collectors audited; owner snapshot/safety not proven'),
'INV-10':('PASS','PASS','PARTIAL','BLOCKED','ROOT_CAUSE_16V.md;UPGRADE_REPRO_16V.md','Full owner incident NOT_REPRODUCED; legacy filter and helper corruption mechanism separately reproduced'),
'REP-01':('PARTIAL','NOT_RUN','PARTIAL','NOT_RUN','UPGRADE_REPRO_16V.md;native action logs/screens','Real UI imports shown; full required UI dataset gate incomplete'),
'REP-02':('PARTIAL','NOT_RUN','PARTIAL','NOT_RUN','UPGRADE_REPRO_16V.md','Recorded24 and all requested graph fixtures must pass in actual native lifecycle'),
'REP-03':('BLOCKED','PARTIAL','BLOCKED','NOT_RUN','UPGRADE_REPRO_16V.md','Immutable connected24 requires real Google MASTER for diary UI; no fake identities'),
'REP-04':('PARTIAL','PARTIAL','PARTIAL','NOT_RUN','UPGRADE_REPRO_16V.md','See actual template/history/capsule cases; authenticated failed/pending queue not created'),
'REP-05':('BLOCKED','NOT_RUN','BLOCKED','NOT_RUN','UPGRADE_REPRO_16V.md','No upgrade PASS allowed before populated UI baseline'),
'REP-06':('PARTIAL','PASS','PARTIAL','BLOCKED','readonly-tool-tests.log;native inventories','Only acquired controlled data, not owner SQLite/media or complete authenticated dataset'),
'REP-07':('PARTIAL','PASS','PARTIAL','BLOCKED','TESTS_16V.md','No real Google MASTER/refresh/account-switch native proof'),
'REP-08':('PARTIAL','PASS','PARTIAL','BLOCKED','TESTS_16V.md;native lifecycle cases','Full DNS/cold/offline behavior on owner data not proven'),
'REP-09':('PARTIAL','PASS','PARTIAL','BLOCKED','legacy scope GREEN;CLIENT unit3;native guest boundary','Real two-account Google native privacy QA not run'),
'FIX-01':('PARTIAL','PASS','PARTIAL','BLOCKED','CHANGES_16V.md;ROOT_CAUSE_16V.md','Minimal alias addresses confirmed partial defect, not entire owner incident'),
'FIX-02':('BLOCKED','BLOCKED','BLOCKED','NOT_RUN','DEPENDENCY_SAFETY_16V.md','Dart no-fallback is insufficient: default Android RW corruption handler can replace corrupt DB'),
'FIX-03':('PARTIAL','NOT_RUN','NOT_RUN','BLOCKED','OWNER_RECOVERY_PLAN_16V.md','No migration introduced or run; any recovery writes require consented snapshot/atomic staging/rollback'),
'FIX-04':('PARTIAL','PASS','PARTIAL','BLOCKED','legacy scope unchanged-row/media test;native inventories','No candidate26/owner media preservation proof'),
'FIX-05':('PARTIAL','PASS','PARTIAL','BLOCKED','legacy scope block-order regression;native inventories','No full diary UI-created/candidate26/owner graph proof'),
'FIX-06':('PARTIAL','PASS','PARTIAL','BLOCKED','TESTS_16V.md','Alias exact server-verified subject MASTER only; actual Google native QA blocked'),
'FIX-07':('PASS','PASS','NOT_RUN','NOT_RUN','OWNER_RECOVERY_PLAN_16V.md;ACQUISITION_OPTIONS_16V.md','No phone actions currently; future acquisition/recovery requires separate consent and proof'),
'FIX-08':('PASS','PASS','NOT_RUN','NOT_RUN','RECOVERY_LIMITATIONS_16V.md','No assumption of missing physical bytes, existing OS backup or automatic cloud recovery'),
'REL-01':('PASS','PASS','NOT_RUN','NOT_RUN','PROGRESS.md;checks.yml','Sulfi APK26 not built or offered; signing/build guard in hotfix branch'),
'REL-02':('BLOCKED','NOT_RUN','NOT_RUN','NOT_RUN','RESULT_16V.md','No candidate26 because safety gates unaccepted; no signing changes'),
'REL-03':('BLOCKED','PARTIAL','BLOCKED','NOT_RUN','UPGRADE_REPRO_16V.md','No actual signed candidate26 full UI-created native preservation proof'),
'REL-04':('PARTIAL','PASS','PARTIAL','BLOCKED','TESTS_16V.md','No candidate26 native library/session/diary full lifecycle'),
'REL-05':('PASS','PASS','NOT_RUN','NOT_RUN','FLUTTER_SUMMARY_16V.json;CI_EVIDENCE_16V.json;TESTS_16V.md','434 Flutter PASS +1 opt-in live SKIP;46+24 Node;3CLIENT;9Python;format/analyze'),
'REL-06':('PASS','PASS','PASS','NOT_RUN','PR46;REMOTE_BASELINES_16V.json;FINAL_BOUNDARIES_16V.json','PR45/main/GAS/ACL/Sulfi signing/old APKs preserved'),
'REL-07':('PARTIAL','PASS','NOT_RUN','NOT_RUN','DRIVE_UPLOADS_16V.json','All final reports/readback must complete before PASS'),
'REL-08':('PASS','PASS','PARTIAL','NOT_RUN','RESULT_16V.md','No emulator or fixture test substituted for owner Android recovery'),
}
latest=reports/'NATIVE_UI_UPGRADE_CURRENT.json'
if latest.exists():
 native=json.loads(latest.read_text());cases={c['case']:c for c in native['cases']}
 if cases.get('native_update24_to25',{}).get('status')=='PASS':
  states['REP-05']=('PASS','NOT_RUN','PASS','NOT_RUN','NATIVE_UI_UPGRADE_CURRENT.json;UPGRADE_REPRO_16V.md','Controlled populated UI dataset only; owner state UNKNOWN; full G1 still BLOCKED')
 if cases.get('before24_inventory',{}).get('status')=='PASS':
  states['REP-01']=('PARTIAL','NOT_RUN','PASS','NOT_RUN','NATIVE_UI_UPGRADE_CURRENT.json','Controlled tracks/modules created via UI; real Google diary not created')
if (reports/'DRIVE_READBACK_16V.json').exists():
 v=json.loads((reports/'DRIVE_READBACK_16V.json').read_text())
 if v.get('allVerified'):
  states['REL-07']=('PASS','PASS','NOT_RUN','NOT_RUN','DRIVE_UPLOADS_16V.json;DRIVE_READBACK_16V.json','Existing Task16 folder, new16V files only; old reports preserved')
with (root/'docs/task16v/ACCEPTANCE_16V.csv').open(newline='') as f:rows=list(csv.DictReader(f))
assert len(rows)==35 and set(states)=={r['ID'] for r in rows}
for row in rows:
 for k,v in zip(['Status','Code','Native','Owner','Evidence','Remaining'],states[row['ID']]):row[k]=v
with (reports/'ACCEPTANCE_16V.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
counts=dict(collections.Counter(r['Status'] for r in rows));assert sum(counts.values())==35
(reports/'ACCEPTANCE_COUNTS_16V.json').write_text(json.dumps({'criteria':35,'status':'BLOCKED_STOP_SHIP','counts':counts,'owner':'PHYSICAL_BYTES_UNKNOWN'},indent=2))
print(counts)
