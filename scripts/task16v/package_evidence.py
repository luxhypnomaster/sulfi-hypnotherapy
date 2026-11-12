"""Package explicit P0 reports/test sources only; never APKs or private databases."""
import argparse
import hashlib
import json
import pathlib
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=pathlib.Path)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    excluded = {'DRIVE_UPLOADS_16V.json', 'DRIVE_READBACK_16V.json',
                'DRIVE_READBACK_CHECKPOINT_16V.json', 'DELIVERY_16V.json',
                'EVIDENCE_MANIFEST_16V.json', 'SHA256SUMS_16V.txt'}
    allowed = {'.md', '.json', '.jsonl', '.csv', '.diff', '.log', '.txt',
               '.xml', '.png', '.py', '.sh', '.java', '.dart', '.yml'}
    candidates = []
    for folder in ('reports/task16v', 'docs/task16v', 'scripts/task16v'):
        candidates.extend((root / folder).rglob('*'))
    candidates.extend(root / name for name in (
        'test/task16v_legacy_draft_visibility_test.dart',
        '.github/workflows/checks.yml'))
    entries = []
    for path in sorted(set(candidates)):
        if not path.is_file() or path.is_symlink():
            continue
        if path.name in excluded or path.suffix not in allowed:
            continue
        # Keep all XML/JSON receipts and representative images; omit repeated
        # launcher/failure images, which remain in Git and private CI logs.
        if path.suffix == '.png' and path.name.startswith(('run6-', 'run7-', 'run11-', 'run12-')):
            if path.name != 'run12-failure-before24_inventory.png':
                continue
        content = path.read_bytes()
        entries.append((path.relative_to(root).as_posix(), content))
    manifest = {'kind': 'REPORTS_AND_CONTROLLED_TEST_EVIDENCE_ONLY',
                'ownerMaterial': 'NONE', 'sulfiAPK26': 'NOT_BUILT_STOP_SHIP',
                'files': [{'path': name, 'bytes': len(data),
                           'sha256': hashlib.sha256(data).hexdigest()}
                          for name, data in entries]}
    args.destination.mkdir(parents=True, exist_ok=True)
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
    (args.destination / 'EVIDENCE_MANIFEST_16V.json').write_bytes(manifest_bytes)
    target = args.destination / 'EVIDENCE_16V.zip'
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, data in entries:
            archive.writestr(name, data)
        archive.writestr('EVIDENCE_MANIFEST_16V.json', manifest_bytes)
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        for entry in manifest['files']:
            data = archive.read(entry['path'])
            assert hashlib.sha256(data).hexdigest() == entry['sha256']
    assert target.stat().st_size < 32 * 1024 * 1024
    checksum = hashlib.sha256(target.read_bytes()).hexdigest()
    (args.destination / 'SHA256SUMS_16V.txt').write_text(f'{checksum}  {target.name}\n')
    print(json.dumps({'files': len(entries), 'bytes': target.stat().st_size,
                      'sha256': checksum, 'crcAndManifestVerified': True}))


if __name__ == '__main__':
    main()
