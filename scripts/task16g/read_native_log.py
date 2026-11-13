"""Recover bounded synthetic-only receipts from private CI logs, verify SHA."""
import base64
import hashlib
import json
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text(errors='replace')
destination = pathlib.Path(sys.argv[2])
digests = dict(re.findall(r'NATIVE16G_DIGEST=([\w.-]+):([a-f0-9]{64})', source))
chunks = {}
for name, index, total, data in re.findall(
    r'NATIVE16G_CHUNK=([\w.-]+):(\d+):(\d+):([A-Za-z0-9+/=]+)', source
):
    count, parts = chunks.setdefault(name, (int(total), {}))
    assert count == int(total)
    if int(index) in parts:
        assert parts[int(index)] == data
    parts[int(index)] = data
assert 'NATIVE_UI_UPGRADE_16G.json' in chunks, 'No native receipt, do not claim upgrade PASS'
receipts = []
for name, (total, parts) in chunks.items():
    assert set(parts) == set(range(total))
    raw = base64.b64decode(''.join(parts[i] for i in range(total)), validate=True)
    assert len(raw) <= 32 * 1024 * 1024
    digest = hashlib.sha256(raw).hexdigest()
    assert digest == digests[name], name
    folder = destination if name.endswith('.json') else destination / 'screens'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / name).write_bytes(raw)
    receipts.append({'file': name, 'bytes': len(raw), 'sha256': digest, 'verified': True})
(destination / 'NATIVE_LOG_READBACK_16G.json').write_text(json.dumps(receipts, indent=2) + '\n')
data = json.loads((destination / 'NATIVE_UI_UPGRADE_16G.json').read_text())
print(json.dumps({'shaVerifiedFiles': len(receipts),
                  'cases': [{'case': c['case'], 'status': c['status'],
                             **({'reason': c['reason']} if 'reason' in c else {})}
                            for c in data['cases']]}, ensure_ascii=False))
