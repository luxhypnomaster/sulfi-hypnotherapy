"""Compare report bytes downloaded from Drive with the exact local output."""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[2] / 'reports/task17'
meta, downloaded, name = json.loads(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
assert pathlib.Path(name).name == name
assert meta['title'] == name
assert meta['parent_ids'] == ['1fXpE8oU3HSE1g89jQppUxFPBgJLh7LqI']
local = root / name if name != 'EVIDENCE_17.zip' else pathlib.Path('/workspace/task17-delivery') / name
expected, actual = local.read_bytes(), downloaded.read_bytes()
assert actual == expected and len(actual) == int(meta['size'])
p = root / 'DRIVE_READBACK_WORK_17.json'
rows = json.loads(p.read_text()) if p.exists() else []
rows = [r for r in rows if r['name'] != name]
rows.append({'name': name, 'id': meta['id'], 'parents': meta['parent_ids'],
             'size': len(actual), 'sha256': hashlib.sha256(actual).hexdigest(),
             'verified': True})
p.write_text(json.dumps(rows, indent=2) + '\n')
print('RAW_SIZE_SHA_PARENT_PASS=' + name)
