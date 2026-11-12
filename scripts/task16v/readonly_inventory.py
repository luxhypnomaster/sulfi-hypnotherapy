"""Read an already acquired, consented forensic COPY. Never contacts a phone.

SQLite/WAL/SHM are copied to a temporary analysis directory. The input files are
opened only for reading; SQLite never opens the source. Output contains hashes,
counts and classifications, not titles, text, Google subjects or credentials.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import sqlite3
import tempfile

TABLES = ('audio_assets', 'module_definitions', 'session_templates',
          'current_draft', 'session_runs', 'diary_author', 'diary_public')

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                    ensure_ascii=False).encode()).hexdigest()

def inventory(root):
    root = pathlib.Path(root).resolve(strict=True)
    db = root / 'library.sqlite'
    evidence = {'kind': 'READ_ONLY_COPY_ANALYSIS', 'ownerRecovery': 'NOT_PROVEN',
                'classes': [], 'databaseFiles': {}, 'tables': {}, 'media': {}}
    if not db.is_file():
        evidence['classes'].append('DB_FILE_MISSING_AT_SUPPLIED_COPY')
        return evidence
    originals = {}
    with tempfile.TemporaryDirectory(prefix='task16v-analysis-') as tmp:
        stage = pathlib.Path(tmp)
        for suffix in ('', '-wal', '-shm'):
            p = root / ('library.sqlite' + suffix)
            if not p.exists():
                continue
            if p.is_symlink() or not p.is_file():
                raise ValueError('Snapshot DB must be a regular file, not symlink')
            originals[p] = digest(p)
            shutil.copyfile(p, stage / p.name)
            evidence['databaseFiles'][p.name] = {'bytes': p.stat().st_size,
                                                'sha256': originals[p]}
        try:
            connection = sqlite3.connect('file:' + str(stage / 'library.sqlite') + '?mode=ro', uri=True)
            connection.row_factory = sqlite3.Row
            try:
                integrity = [r[0] for r in connection.execute('pragma integrity_check')]
                evidence['integrity'] = integrity
                evidence['schema'] = connection.execute('pragma user_version').fetchone()[0]
                if integrity != ['ok']:
                    evidence['classes'].append('SQLITE_INTEGRITY_ERROR')
                available = {r[0] for r in connection.execute("select name from sqlite_master where type='table'")}
                for table in TABLES:
                    if table not in available:
                        evidence['tables'][table] = {'state': 'TABLE_MISSING'}
                        continue
                    rows = [dict(r) for r in connection.execute('select * from ' + table)]
                    evidence['tables'][table] = {
                        'count': len(rows), 'state': 'ROWS_PRESENT' if rows else 'ROWS_ABSENT_AT_SNAPSHOT',
                        'rows': sorted(fingerprint(r) for r in rows)}
                    for row in rows:
                        if table == 'audio_assets':
                            rel = row.get('filePath')
                            if not isinstance(rel, str) or pathlib.Path(rel).name != rel:
                                evidence['classes'].append('LEGACY_OR_UNSAFE_MEDIA_PATH')
                                continue
                            media = root / 'audio' / rel
                            key = fingerprint(row.get('id'))
                            if media.is_symlink():
                                evidence['media'][key] = {'state': 'SYMLINK_NOT_FOLLOWED'}
                            elif not media.is_file():
                                evidence['media'][key] = {'state': 'FILE_BYTES_MISSING_REFERENCES_PRESENT'}
                                evidence['classes'].append('FILE_BYTES_MISSING_REFERENCES_PRESENT')
                            else:
                                actual = digest(media)
                                evidence['media'][key] = {'bytes': media.stat().st_size,
                                    'sha256': actual, 'matchesMetadata': row.get('contentHash') in (None, actual)}
                        elif table in ('module_definitions', 'session_templates', 'diary_author'):
                            try:
                                value = json.loads(row['payload'])
                                if not isinstance(value, dict):
                                    raise ValueError('Expected object')
                            except (ValueError, TypeError, KeyError):
                                evidence['classes'].append('MALFORMED_PAYLOAD_PRESERVED')
            finally:
                connection.close()
        except sqlite3.Error as error:
            evidence['classes'].append('SQLITE_READ_ERROR')
            evidence['sqliteErrorClass'] = type(error).__name__
    if any(digest(p) != before for p, before in originals.items()):
        raise RuntimeError('SOURCE_CHANGED_DURING_READ; reject evidence')
    evidence['sourceUnchanged'] = True
    evidence['classes'] = sorted(set(evidence['classes']))
    # Presence does not prove UI visibility, identity, historical deletion or recovery.
    if not evidence['classes']:
        evidence['classes'] = ['COPY_READABLE_PHYSICAL_OWNER_STATE_UNKNOWN']
    return evidence

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('snapshot_directory', type=pathlib.Path)
    args = p.parse_args()
    print(json.dumps(inventory(args.snapshot_directory), ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
