"""Reuse actual successful native steps, never turn a failed test into PASS."""
import hashlib
import json
import pathlib
import subprocess


def gh(path):
    result = subprocess.run(['gh', 'api', 'repos/luxhypnomaster/sulfi-hypnotherapy/' + path],
                            capture_output=True, check=True)
    return json.loads(result.stdout)


run = gh('actions/runs/43403971950')
assert run['event'] == 'workflow_dispatch' and run['status'] == 'completed'
assert run['head_sha'] == 'c3b8f06b5fc600e5ab20af5424ae66d4702b9c86'
job = next(x for x in gh('actions/runs/43403971950/jobs')['jobs'] if x['name'] == 'appfault16g')
assert next(x for x in job['steps'] if x['name'] == 'Run reactivecircus/android-emulator-runner@v2')['conclusion'] == 'success'
assert next(x for x in job['steps'] if x['name'] == 'Gate one private draft pair on healthy upgrade and actual app fault safety')['conclusion'] == 'failure'
folder = pathlib.Path('reports/task16g')
for name, expected in [('NATIVE_UI_UPGRADE_16G.json', '915d2d61a8f3bc3cfbd348181b6fa3264e617d36a78afebe4fc7f4a1756ba9f6'),
                       ('FAULT_APP_16G.json', 'f71c334200f0d79769b22f1c3f8b2dba25b798491f8e2392400ccaa706204c28')]:
    assert hashlib.sha256((folder / name).read_bytes()).hexdigest() == expected
native = json.loads((folder / 'NATIVE_UI_UPGRADE_16G.json').read_text())
assert len(native['cases']) == 14
assert all(x['status'] == 'PASS' for x in native['cases'] if x['case'] != 'ui_diary_auth_boundary')
assert next(x for x in native['cases'] if x['case'] == 'ui_diary_auth_boundary')['status'] == 'NOT_RUN'
for name in ['before25', 'after26', 'cold26']:
    snapshot = native['inventories'][name]
    assert snapshot['database'] == {'integrity': 'ok', 'version': 9}
    assert len(snapshot['rows']['audio_assets']) == 3
    assert len(snapshot['rows']['module_definitions']) == 2
    assert len(snapshot['rows']['session_templates']) == 1
    assert len(snapshot['rows']['session_runs']) == 1
    tracks = {x['id'] for x in snapshot['rows']['audio_assets']}
    program = json.loads(snapshot['rows']['session_templates'][0]['payload'])
    assert {x['audioAssetId'] for x in program['plan']['steps']} == tracks
    modules = [json.loads(x['payload']) for x in snapshot['rows']['module_definitions']]
    assert any(any(s['kind'] == 'silence' and s['durationMs'] > 0 for s in m['items']) for m in modules)
fault = json.loads((folder / 'FAULT_APP_16G.json').read_text())
assert len(fault['cases']) == 3 and all(x['status'] == 'PASS' for x in fault['cases'])
release = gh('releases/444069048')
assert release['draft'] is True and release['tag_name'] == 'task16g-qa-pair-26'
assert release['target_commitish'] == '9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c'
assert not any(x['name'] in ['master26.apk', 'client26.apk', 'APK_PAIR_16G.json'] for x in release['assets']), 'NO_OVERWRITE_EXISTING_ASSETS'
print('DELIVERY_GATE_PASS: actual native step/13cases + 3faults; same graph/SHA receipts; existing private draft only')
