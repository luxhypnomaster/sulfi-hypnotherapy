import hashlib
import importlib.util
import json
import pathlib
import sqlite3
import tempfile
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
    def test_legacy_external_path_not_followed(self):
        c=self.db();c.execute("insert into audio_assets values ('id','/private/elsewhere',null)");c.commit();c.close()
        self.assertIn('LEGACY_OR_UNSAFE_MEDIA_PATH',module.inventory(self.root)['classes'])

if __name__ == '__main__':unittest.main()
