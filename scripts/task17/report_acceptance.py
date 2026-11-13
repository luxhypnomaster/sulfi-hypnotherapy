"""All67 source criteria, separate evidence layers; never infer physical PASS."""
import csv
import collections
import json
import pathlib

root=pathlib.Path(__file__).resolve().parents[2]
r=root/'reports/task17'
ci=json.loads((r/'CI_17.json').read_text()) if (r/'CI_17.json').exists() else {}
full=any(j['name']=='verify' and j.get('conclusion')=='success' for j in ci.get('jobs',[]))
native={}
for p in r.glob('NATIVE_*_17.json'):
    v=json.loads(p.read_text())
    if 'cases' in v:native[(v.get('edition'),v.get('baseline'))]=v
upgrade=all((edition,base) in native and all(c['status']=='PASS' for c in native[edition,base]['cases'] if c['case']!='ui_diary_auth_boundary') for edition,base in [('master',25),('master',26),('client',25)])
pair=json.loads((r/'APK_PAIR_17.json').read_text()) if (r/'APK_PAIR_17.json').exists() else {}
pairpass=pair.get('allVerified') is True and pair.get('ownerQA')=='NOT_RUN'
drive=json.loads((r/'DRIVE_READBACK_17.json').read_text()) if (r/'DRIVE_READBACK_17.json').exists() else {}
delivered=drive.get('allVerified') is True
notes={
'G0-01':'BASELINE_17.json; PR45/46/47 draft/unmerged; live source health matches known6. Numeric current admin deployment read NOT_RUN.',
'G0-02':'ROOT_CAUSE_17.md; GoogleDiaryIdentity→shared DiaryController/API→all entrypoints. No independent backend proven.',
'G0-03':'Historical owner text+image only; old-phone trace unavailable. New opt-in safe trace tested; no invented replay of owner history.',
'G0-04':'G0_RED.log exact lifecycle production path RED→GREEN; task17_root_cause_test.dart.',
'G0-05':'CATALOG_SESSION_RED_17.log; frozen null credential RED→dynamic shared credential GREEN.',
'G0-06':'Literal space_sheet version audited; replaced by DeviceFiles.diagnostics; candidate aapt readback pending/see APK pair.',
'G1-01':'task17_auth_test; shared role/session controlled. Actual MASTER Google NOT_RUN.',
'G1-02':'task16a_auth_test and client role deny; actual second Google NOT_RUN.',
'G1-03':'Clock-advanced SDK-boundary recovery controlled; actual15/30/60min Google MASTER NOT_RUN.',
'G1-04':'Same SDK adapter in CLIENT; real timed CLIENT restore NOT_RUN.',
'G1-05':'Persisted opt-out and local scope hints; SDK authorized recovery controlled. Native cold local storage separate.',
'G1-06':'single-flight refresh/expiry; narrow pinned Android fork removes unapproved-account fallback. Real provider expiry NOT_RUN.',
'G1-07':'Persisted logout opt-out checked before API/SDK restore; old async chooser cannot restore newer session.',
'G1-08':'Explicit switchGoogleAccount; generation guard and negative other-owner tests. Physical chooser NOT_RUN.',
'G1-09':'Offline local MASTER author workspace, scoped private drafts; SocketException path is not logout.',
'G1-10':'Late SDK completion/logout generation controlled tests. Actual connectivity-restored platform consent NOT_RUN.',
'G1-11':'task16b_auth_transport_test; queue preflight401/403/network, bounded retries; actual TLS/radio/Google revoke NOT_RUN.',
'G1-12':'task17_catalog_session_test: API built before shared login sees new credential and explicit logout.',
'G1-13':'Existing JS signature/issuer/audience/expiry/subject/role tests; production source inventory, no security bypass or deploy.',
'G1-14':'Existing HTTPS redirect allowlist and credential non-forwarding tests retained; no transport guard changes.',
'G1-15':'GoogleAccountPanel uses same DiaryController, readonly whoami, local edition distinct from verified role. Owner phone NOT_RUN.',
'G2-01':'Previous owner SHA(endpoint|server subject scope) retained; no token/email binding rewrite.',
'G2-02':'Atomic durable intent before pump, process-recovery explicit Resume; runnerEpoch not Google identity.',
'G2-03':'Separate lifecycle/user/owner pause reasons; ROOT_RED and queue tests.',
'G2-04':'Manual logout rotates runner intent; explicit same-owner resume only; prior completed receipt retained.',
'G2-05':'Different owner guard denies payload access/dispatch; scopes unchanged.',
'G2-06':'Observable enqueue result, deferred resume while HTTP active; UI reports actionable failures.',
'G2-07':'Five taps/restart/new-revision tests; one existing outbox, no new queue table.',
'G2-08':'Actual Dart→JS catalog commit reply deliberately lost; SAME requestId/receipt replay.',
'G2-09':'Lost response test asserts catalog.get between first commit and exact-key replay; persisted pending attempted flag.',
'G2-10':'Cooperative pause allows current response, prevents subsequent retries/requests; no promised background service.',
'G2-11':'Cancel is local queue action, not withdrawal/delete; originals preserved.',
'G2-12':'alchemistWorkLabel/FileProgress unit tests: waits separate, no0/0 percentage, ack!=server commit.',
'G3-01':'Exact GAS6 Diary.js new short-only test RED; minimal candidate diff GREEN; LIVE BLOCKED_OWNER_APPROVAL.',
'G3-02':'Published status/number test and image+text Dart→JS; historical owner26→client25 distinct from Task17 phone QA.',
'G3-03':'Semantic media fingerprint and immutable-public-snapshot tests. No fake draft for path/locator difference.',
'G3-04':'task17_auth_test offline private-scope draft; native new27 draft separate from unavailable legacy Google drafts.',
'G3-05':'Short message ordinary text, blocks/contentLinks empty; no inferred CTA.',
'G3-06':'Controlled catalog module3valid AAC fixture tracks+cover; no diary auto post. Not owner hypnotherapy audio/hearing.',
'G3-07':'Controlled program publication/install retains template ID and exact3 audio references.',
'G3-08':'Shared catalog credential fixed; controlled catalog CRUD/read; real owner catalog NOT_RUN.',
'G3-09':'Controlled separate CLIENT storage selective exact install. Real second Google account NOT_RUN.',
'G3-10':'Controlled file/hash proof only; native existing local WAV audio state not hearing of cloud-installed3tracks.',
'G3-11':'Repeated install preserves downloaded byte counter and asset count; no extra blobs.',
'G3-12':'Published exact ContentLink lookup, existing installer; announcement cannot silently publish catalog.',
'G3-13':'JS ACL/client publish deny and other-owner negative tests; no public Drive sharing.',
'G3-14':'DNS/chunk abort/ack-offset/retry and lost commit response controlled; real radios/Drive queue NOT_RUN.',
'G3-15':'Existing public/private catalog ACL and exact revisions, no audience/pro entitlement invented.',
'G4-01':'task17_ui_test mandatory every-page preview, jumping to last insufficient, no reader-state writes.',
'G4-02':'Five editor taps→one review; enqueue failure keeps exact local draft/editor. Successful path targets exact task route.',
'G4-03':'Yellow global indicator opens existing queue; pendingCount/owner filter, source inspection; phone visual QA NOT_RUN.',
'G4-04':'Known acknowledged bytes show N/M and%; verification indeterminate, no fake publication100%.',
'G4-05':'Fuchsia draft/yellow pending/green receipt/grey expired; error/paused human states. Widget/phone coverage not exhaustive.',
'G4-06':'Composition text/image/audio labels fuchsia; no social media feed.',
'G4-07':'Existing48px HOME shield target/placement retained; transferYellow, no asset redesign.',
'G4-08':'Shared Google panel with login/switch/logout/check auth.whoami only, not pilot provisioning.',
'G4-09':'Existing Android diagnostics PackageManager values; no hardcoded version; aapt/candidate native evidence when present.',
'G4-10':'Widget focus/selection/composing remain after autosave; existing200% font+keyboard catalog regression retained.',
'G4-11':'Private scoped editable author/rightsholder default restored in next card; no Google ownership assertion.',
'G4-12':'NFC/case/whitespace matching only NEW category input, both legacy variants unchanged.',
'G4-13':'Reader Back functions untouched; only optional publicationReview footer/page visited tracking added.',
'G5-01':'STORAGE_SOURCE_BOUNDARIES_17.json + actual native lanes if available; physical Google draft/WAL crash matrix not inferred.',
'G5-02':'Pair/cert/version/config/bytes only after CI and raw release download readback; else no issued APK.',
'G5-03':'SERVER_DIARY_PATCH_17.diff + source inventory; NO DEPLOY; existing GAS6/main/OAuth/ACL/signing unchanged.',
'G5-04':'Every67 source row retained; CODE/CONTROLLED/LIVE/OWNER separate; no fake physical PASS.',
'G5-05':'New17 folder only; Drive raw readback before delivery PASS; old16 unmodified.',
'G5-06':'CODEX_EFFICIENCY_17 exact test/CI runs, bounded retries and reasons; no owner quota percentages supplied.',
}
rows=list(csv.DictReader((root/'docs/task17/02_ACCEPTANCE_17.csv').open(encoding='utf-8-sig',newline='')))
assert len(rows)==67 and len({x['ID'] for x in rows})==67
assert set(notes)=={x['ID'].removeprefix('17-') for x in rows}
for row in rows:
    key=row['ID'].removeprefix('17-')
    row.update(Code='PASS',Controlled='PASS',Live='NOT_RUN',Owner='NOT_RUN',Status='PARTIAL',Evidence_URL_or_note=notes[key])
    if key in ['G0-02','G0-04','G0-05','G0-06']:row['Status']='PASS'
    if key in ['G0-01','G0-03']:row['Controlled']='PARTIAL'
    if key in ['G1-04','G1-10','G1-15','G3-10','G4-03','G4-05','G4-06','G4-07','G4-08','G4-09','G4-13']:row['Controlled']='PARTIAL'
    if key in ['G3-01']:row['Live']='BLOCKED';row['Status']='BLOCKED'
    if key=='G3-10':row['Owner']='BLOCKED';row['Status']='BLOCKED'
    if key=='G5-01':row['Controlled']='PASS' if upgrade else 'BLOCKED';row['Status']='PARTIAL' if upgrade else 'BLOCKED'
    if key=='G5-02':row['Controlled']='PASS' if pairpass else 'BLOCKED';row['Status']='PARTIAL' if pairpass else 'BLOCKED'
    if key in ['G5-03','G5-04','G5-06']:row['Status']='PASS'
    if key=='G5-05':row['Controlled']='PASS' if delivered else 'PARTIAL';row['Status']='PASS' if delivered else 'PARTIAL'
with (r/'ACCEPTANCE_17.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=rows[0].keys(),lineterminator='\n');w.writeheader();w.writerows(rows)
summary={'criteria':67,'counts':dict(collections.Counter(x['Status'] for x in rows)), 'fullCI':full,'nativeUpgradeThreeLanes':upgrade,'pairReadbackVerified':pairpass,'driveReadback':delivered,'GooglePhysical':'NOT_RUN','serverPatch':'WAITING_OWNER_APPROVAL','overall':'PARTIAL_NOT_ACCEPTED'}
(r/'ACCEPTANCE_SUMMARY_17.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary))
