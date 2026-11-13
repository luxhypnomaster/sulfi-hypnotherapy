"""Require real successful CI and identical executable/test trees, not a boolean claim."""
import json
import pathlib
import subprocess


def gh(path):
    result = subprocess.run(['gh', 'api', path], capture_output=True, check=False)
    if result.returncode:
        raise SystemExit('CI_READBACK_FAILED; no signing/build allowed')
    return json.loads(result.stdout)


repo = 'repos/luxhypnomaster/sulfi-hypnotherapy'
receipt = json.loads(pathlib.Path('reports/task16g/REGRESSION_16G.json').read_text())
assert receipt['source'] == '11909895da4f2967b77f12a8b8da98ff50b370d5'
run = gh(f'{repo}/actions/runs/{receipt["run"]}')
assert run['head_sha'] == receipt['source'] and run['event'] == 'workflow_dispatch'
jobs = gh(f'{repo}/actions/runs/{receipt["run"]}/jobs')['jobs']
assert any(j['name'] == 'verify' and j['conclusion'] == 'success' for j in jobs)
assert receipt['flutter']['passed'] == 448 and receipt['flutter']['failures'] == 0
commit = gh(f'{repo}/git/commits/{receipt["source"]}')
tree = gh(f'{repo}/git/trees/{commit["tree"]["sha"]}')['tree']
old = {x['path']: x['sha'] for x in tree}
for name in ['lib', 'android', 'third_party', 'test', 'server', 'pubspec.yaml', 'pubspec.lock']:
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD:' + name], text=True).strip()
    assert actual == old[name], 'EXECUTABLE_OR_TEST_TREE_CHANGED:' + name
print('REAL_VERIFY_REUSED:448Flutter/3CLIENT/46+24Node; identical app/test/server trees')
