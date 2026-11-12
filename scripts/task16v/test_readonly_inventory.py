import hashlib
import importlib.util
import json
import pathlib
import sqlite3
import tempfile
import subprocess
import sys
import unittest

spec = importlib.util.spec_from_file_location('readonly16v', pathlib.Path(__file__).with_name('readonly_inventory.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ReadOnly16V(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
    def tearDown(self):
        self.tmp.cleanup()
    def db(self):
        c = sqlite3.connect(self.root / 'library.sqlite')
        c.execute('create table audio_assets(id text, filePath text, contentHash text)')
        c.execute('create table diary_author(id text, payload text)')
        c.execute('pragma user_version=9')
        c.commit()
        return c
    def test_absent_database_is_not_created(self):
        v = module.inventory(self.root)
        self.assertEqual(v['classes'], ['DB_FILE_MISSING_AT_SUPPLIED_COPY'])
        self.assertFalse((self.root/'library.sqlite').exists())
    def test_wal_rows_and_exact_source_bytes_preserved(self):
        c = self.db()
        c.execute('pragma journal_mode=WAL')
        (self.root/'audio').mkdir()
        data = b'controlled-test-only'
        (self.root/'audio/existing.m4a').write_bytes(data)
        c.execute('insert into audio_assets values (?,?,?)', ('private-title-like-id', 'existing.m4a', hashlib.sha256(data).hexdigest()))
        c.execute('insert into diary_author values (?,?)', ('private-id', json.dumps({'title':'PRIVATE TITLE NOT OUTPUT'})))
        c.commit()
        before = {p.name:p.read_bytes() for p in self.root.glob('library.sqlite*')}
        v = module.inventory(self.root)
        self.assertEqual(v['tables']['audio_assets']['count'], 1)
        self.assertEqual(v['tables']['diary_author']['count'], 1)
        self.assertEqual(v['integrity'], ['ok'])
        self.assertTrue(v['sourceUnchanged'])
        self.assertNotIn('PRIVATE TITLE', json.dumps(v))
        self.assertNotIn('private-title-like-id', json.dumps(v))
        self.assertEqual(before, {p.name:p.read_bytes() for p in self.root.glob('library.sqlite*')})
        c.close()
    def test_missing_media_does_not_delete_reference(self):
        c = self.db()
        c.execute("insert into audio_assets values ('id','missing.m4a',null)")
        c.commit();c.close()
        v = module.inventory(self.root)
        self.assertIn('FILE_BYTES_MISSING_REFERENCES_PRESENT',v['classes'])
        self.assertEqual(v['tables']['audio_assets']['count'],1)
    def test_corrupt_db_stays_identical_no_fallback(self):
        p = self.root/'library.sqlite';p.write_bytes(b'NOT A DATABASE')
        v = module.inventory(self.root)
        self.assertIn('SQLITE_READ_ERROR',v['classes'])
        self.assertEqual(p.read_bytes(),b'NOT A DATABASE')
    def test_bad_payload_is_reported_without_rewrite(self):
        c=self.db();c.execute("insert into diary_author values ('invalid','{')");c.commit();c.close()
        self.assertIn('MALFORMED_PAYLOAD_PRESERVED',module.inventory(self.root)['classes'])
    def test_rollback_journal_is_inventoried_and_source_preserved(self):
        c=self.db();c.close()
        journal=self.root/'library.sqlite-journal';journal.write_bytes(b'')
        v=module.inventory(self.root)
        self.assertIn('library.sqlite-journal',v['databaseFiles'])
        self.assertEqual(v['databaseFiles']['library.sqlite-journal']['bytes'],0)
        self.assertEqual(journal.read_bytes(),b'')
        self.assertTrue(v['sourceUnchanged'])
    def test_hot_rollback_crash_copy_never_recovers_or_changes_source(self):
        script="""import sqlite3,sys,time
c=sqlite3.connect(sys.argv[1]);c.execute('pragma journal_mode=DELETE');c.execute('pragma synchronous=FULL');c.execute('pragma cache_size=4')
c.execute('create table diary_author(id text,payload text)');c.executemany('insert into diary_author values (?,?)',[(str(i),'x'*4096) for i in range(200)]);c.commit()
c.execute('begin immediate');c.execute("update diary_author set payload=?",('y'*4096,));print('READY',flush=True);time.sleep(300)
"""
        child=subprocess.Popen([sys.executable,'-c',script,str(self.root/'library.sqlite')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            self.assertEqual(child.stdout.readline().strip(),'READY')
        finally:
            child.kill();child.wait(timeout=10)
            child.stdout.close();child.stderr.close()
        journal=self.root/'library.sqlite-journal'
        self.assertGreater(journal.stat().st_size,0)
        before={p.name:p.read_bytes() for p in self.root.glob('library.sqlite*')}
        v=module.inventory(self.root)
        self.assertIn('library.sqlite-journal',v['databaseFiles'])
        self.assertIn('SQLITE_READ_ERROR',v['classes'])
        self.assertTrue(v['sourceUnchanged'])
        self.assertEqual(before,{p.name:p.read_bytes() for p in self.root.glob('library.sqlite*')})
    def test_symlink_audio_directory_not_followed(self):
        c=self.db();c.execute("insert into audio_assets values ('id','outside.m4a',null)");c.commit();c.close()
        outside=self.root/'outside';outside.mkdir();(outside/'outside.m4a').write_bytes(b'PRIVATE_DO_NOT_FOLLOW')
        (self.root/'audio').symlink_to(outside,target_is_directory=True)
        v=module.inventory(self.root)
        self.assertEqual(next(iter(v['media'].values()))['state'],'SYMLINK_NOT_FOLLOWED')
    def test_queue_and_scope_settings_are_counted_but_never_disclosed(self):
        c=self.db();c.execute('create table app_settings(name text,value text)')
        c.execute('insert into app_settings values (?,?)',('alchemist_diary_queue:private-id',json.dumps({'scope':'google:PRIVATE_OWNER_SUBJECT','credential':'PRIVATE_TOKEN_NOT_OUTPUT','entry':{'message':'PRIVATE_CONTENT'}})))
        c.commit();c.close()
        v=module.inventory(self.root)
        self.assertEqual(v['tables']['app_settings']['count'],1)
        output=json.dumps(v)
        for secret in ['PRIVATE_OWNER_SUBJECT','PRIVATE_TOKEN_NOT_OUTPUT','PRIVATE_CONTENT','private-id']:
            self.assertNotIn(secret,output)
    def test_legacy_external_path_not_followed(self):
        c=self.db();c.execute("insert into audio_assets values ('id','/private/elsewhere',null)");c.commit();c.close()
        self.assertIn('LEGACY_OR_UNSAFE_MEDIA_PATH',module.inventory(self.root)['classes'])

if __name__ == '__main__':unittest.main()
