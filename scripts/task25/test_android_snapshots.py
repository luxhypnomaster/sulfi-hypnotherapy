"""Archive/SQLite-copy reader tests, not an Android or Google identity test."""
import copy
import hashlib
import io
import json
from pathlib import Path
import sqlite3
import tarfile
import tempfile
import unittest

import check_android_snapshots as s


class SnapshotCopiesTest(unittest.TestCase):
    def fixture(self, root, wal=False):
        original=root/'original';original.mkdir()
        c=sqlite3.connect(original/'library.sqlite')
        if wal:c.execute('pragma journal_mode=wal');c.execute('pragma wal_autocheckpoint=0')
        for name in s.TABLES:c.execute('CREATE TABLE "'+name+'" (id TEXT PRIMARY KEY, value TEXT)')
        c.execute('pragma user_version=9');c.commit()
        if wal:c.execute('pragma wal_checkpoint(truncate)')
        c.execute('INSERT INTO audio_assets VALUES (?,?)',('synthetic-unit-reader','EXACT_OLD_BYTES_REFERENCE'));c.commit()
        c.row_factory=sqlite3.Row
        rows={name:[dict(r) for r in c.execute('SELECT * FROM "'+name+'"')] for name in s.TABLES}
        archive=root/'beforeBaseline-private-snapshot.tar';files={}
        with tarfile.open(archive,'w') as z:
            for p in original.iterdir():
                b=p.read_bytes();name='files/'+p.name
                files[name]={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
                info=tarfile.TarInfo(name);info.size=len(b);z.addfile(info,io.BytesIO(b))
        c.close()
        report={'applicationSourceSHA':s.SOURCE,'baseline':28,'candidate':s.CODE,'ownerPhone':'NOT_TOUCHED','realGoogle':'NOT_RUN',
                'inventories':{'beforeBaseline':{'snapshot_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
                     'files':files,'rows':rows,'database':{'integrity':'ok','version':9}}}}
        return report,archive

    def test_actual_readonly_wal_copy_reads_committed_rows_without_changing_archive(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);report,archive=self.fixture(root,wal=True);before=archive.read_bytes()
            self.assertIn('files/library.sqlite-wal',report['inventories']['beforeBaseline']['files'])
            proof=s.check(report,root)
            self.assertEqual(proof['inventories'][0]['nativeTablesIndependentlyRead'],15)
            self.assertEqual(archive.read_bytes(),before)
            self.assertFalse(proof['rawPrivateDataPublished'])
            self.assertNotIn('EXACT_OLD_BYTES_REFERENCE',json.dumps(proof))

    def test_report_cannot_hide_an_actual_missing_row_or_changed_file_hash(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);report,_=self.fixture(root)
            bad=copy.deepcopy(report);bad['inventories']['beforeBaseline']['rows']['audio_assets']=[]
            with self.assertRaisesRegex(ValueError,'ROWS_MISMATCH_audio_assets'):s.check(bad,root)
            bad=copy.deepcopy(report);bad['inventories']['beforeBaseline']['files']['files/library.sqlite']['sha256']='0'*64
            with self.assertRaisesRegex(ValueError,'FILE_SHA_MISMATCH'):s.check(bad,root)

    def test_traversal_and_links_rejected_even_when_archive_sha_is_updated(self):
        for link in [False,True]:
            with self.subTest(link=link),tempfile.TemporaryDirectory() as td:
                root=Path(td);report,archive=self.fixture(root)
                with tarfile.open(archive,'a') as z:
                    info=tarfile.TarInfo('files/escape' if link else '../outside')
                    if link:
                        info.type=tarfile.SYMTYPE;info.linkname='/not-read-or-created';z.addfile(info)
                    else:
                        info.size=1;z.addfile(info,io.BytesIO(b'x'))
                report['inventories']['beforeBaseline']['snapshot_sha256']=hashlib.sha256(archive.read_bytes()).hexdigest()
                with self.assertRaisesRegex(ValueError,'UNSAFE_NATIVE_ARCHIVE_MEMBER'):s.check(report,root)

    def test_owner_or_noncontrolled_report_is_never_accepted_as_a_native_fixture(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);report,_=self.fixture(root)
            report['ownerPhone']='PASS'
            with self.assertRaisesRegex(ValueError,'CONTROLLED_NATIVE_REPORT_REQUIRED'):s.check(report,root)

    def test_actual_native_inventory_wav_basename_is_a_safe_filename(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);report,archive=self.fixture(root)
            report['inventories']['after-ui-import-task16v-1.wav']=report['inventories'].pop('beforeBaseline')
            archive.rename(root/'after-ui-import-task16v-1.wav-private-snapshot.tar')
            self.assertEqual(s.check(report,root)['status'],'PASS_INDEPENDENT_ANDROID_SNAPSHOT_COPIES')
