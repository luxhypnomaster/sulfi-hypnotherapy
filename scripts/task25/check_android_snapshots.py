#!/usr/bin/env python3
"""Independent read-only verification of controlled Android artifact copies.

Never opens a phone/original database; extracts only SQLite sidecars into an
isolated temporary directory. Output contains hashes/counts, not private rows.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sqlite3
import tarfile
import tempfile

from candidate25 import SOURCE, CODE
from verify_native_evidence import TABLES

DB_FILES = {'files/library.sqlite', 'files/library.sqlite-wal',
            'files/library.sqlite-shm', 'files/library.sqlite-journal'}


def check(report, snapshots, temp_parent=None):
    if not (report.get('applicationSourceSHA') == SOURCE and report.get('baseline') == 28
            and report.get('candidate') == CODE and report.get('ownerPhone') == 'NOT_TOUCHED'
            and report.get('realGoogle') == 'NOT_RUN'):
        raise ValueError('CONTROLLED_NATIVE_REPORT_REQUIRED_NOT_OWNER_DATA')
    inventories = report.get('inventories', {})
    if not inventories:
        raise ValueError('NO_ACTUAL_SNAPSHOT_INVENTORIES')
    records = []
    for name, inv in inventories.items():
        if not re.fullmatch(r'[A-Za-z0-9_.-]{1,80}', name) or name in {'.','..'}:
            raise ValueError('UNSAFE_INVENTORY_NAME')
        archive = Path(snapshots) / (name + '-private-snapshot.tar')
        if archive.is_symlink() or not archive.is_file():
            raise ValueError('REGULAR_NATIVE_ARCHIVE_REQUIRED')
        if archive.stat().st_size > 130 * 1024**2:
            raise ValueError('CONTROLLED_ARCHIVE_BOUNDS')
        with archive.open('rb') as f:
            sha = hashlib.file_digest(f, 'sha256').hexdigest()
        if sha != inv.get('snapshot_sha256'):
            raise ValueError('NATIVE_ARCHIVE_SHA_MISMATCH')
        with tempfile.TemporaryDirectory(dir=temp_parent) as temp_dir:
            copied = Path(temp_dir)
            files = {}
            with tarfile.open(archive, mode='r:') as z:
                members = z.getmembers()
                if (len(members) > 1000 or sum(m.size for m in members) > 128 * 1024**2
                        or any(m.size < 0 or m.size > 32 * 1024**2 for m in members)):
                    raise ValueError('CONTROLLED_ARCHIVE_BOUNDS')
                seen = set()
                for m in members:
                    q = PurePosixPath(m.name)
                    if (q.is_absolute() or '..' in q.parts or '\\' in m.name
                            or not q.parts or q.parts[0] not in {'files', 'shared_prefs'}
                            or m.name in seen or not (m.isfile() or m.isdir())):
                        raise ValueError('UNSAFE_NATIVE_ARCHIVE_MEMBER')
                    seen.add(m.name)
                    if not m.isfile():
                        continue
                    b = z.extractfile(m).read()
                    files[m.name] = {'bytes':len(b), 'sha256':hashlib.sha256(b).hexdigest()}
                    if files[m.name] != inv.get('files', {}).get(m.name):
                        raise ValueError('ACTUAL_PRIVATE_FILE_SHA_MISMATCH')
                    if m.name in DB_FILES:
                        (copied / q.name).write_bytes(b)
            expected_private = {k:v for k,v in inv.get('files', {}).items()
                                if k.startswith(('files/', 'shared_prefs/'))}
            if files != expected_private:
                raise ValueError('EXACT_PRIVATE_FILE_SET_MISMATCH')
            if not (copied / 'library.sqlite').is_file():
                raise ValueError('ACTUAL_SQLITE_COPY_REQUIRED')
            connection = sqlite3.connect('file:' + str(copied / 'library.sqlite') + '?mode=ro', uri=True)
            try:
                connection.row_factory = sqlite3.Row
                headers = {'integrity':connection.execute('pragma integrity_check').fetchone()[0],
                           'version':connection.execute('pragma user_version').fetchone()[0]}
                if headers != inv.get('database') or headers != {'integrity':'ok', 'version':9}:
                    raise ValueError('ACTUAL_SQLITE_INTEGRITY_OR_SCHEMA_MISMATCH')
                for table in TABLES:  # Constant allowlist, never SQL from an archive.
                    actual = [dict(r) for r in connection.execute('SELECT * FROM "' + table + '"')]
                    sort_key = lambda row: json.dumps(row, sort_keys=True)
                    if sorted(actual, key=sort_key) != sorted(inv.get('rows', {}).get(table, []), key=sort_key):
                        raise ValueError('ACTUAL_SQLITE_ROWS_MISMATCH_' + table)
            finally:
                connection.close()
        records.append({'inventory':name, 'archiveSHA256':sha, 'nativeTablesIndependentlyRead':len(TABLES),
                        'privateFilesHashed':len(files), 'integrity':'ok', 'schema':9})
    return {'status':'PASS_INDEPENDENT_ANDROID_SNAPSHOT_COPIES', 'inventories':records,
            'originalArchivesChanged':False, 'rawPrivateDataPublished':False,
            'externalSAFCapsule':'NOT_IN_PRIVATE_TAR_REPORT_SHA_ONLY',
            'physicalPhone':'NOT_RUN', 'realGoogle':'NOT_RUN'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('snapshots', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--temp-parent', type=Path)
    args = parser.parse_args()
    result = json.dumps(check(json.loads(args.report.read_text()), args.snapshots, args.temp_parent), indent=2) + '\n'
    if args.output:
        with args.output.open('x') as f:  # Never replace a source/report/database.
            f.write(result)
    else:
        print(result, end='')


if __name__ == '__main__':
    main()
