"""Synthetic crash-format tests, never an Android pass or real guest memory."""
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest

import emulator_fault25 as m


def fixture():
    name='/sdk/emulator/lib64/libgfxstream_backend.so'.encode('utf-16le')
    sys,exc,mods,ctx,text=80,136,304,416,672
    memory=text+4+len(name)
    data=bytearray(memory+128)
    struct.pack_into('<IIIIIIQ',data,0,0x504d444d,0xa793,4,32,0,0,0)
    for i,(kind,length,rva) in enumerate([(7,56,sys),(6,168,exc),(4,112,mods),(5,64,memory)]):
        struct.pack_into('<III',data,32+i*12,kind,length,rva)
    struct.pack_into('<H',data,sys,9)
    struct.pack_into('<I',data,exc,123)
    struct.pack_into('<IIQQII',data,exc+8,0x4000000b,0,0,0x100321,0,0)
    struct.pack_into('<II',data,exc+160,256,ctx)
    struct.pack_into('<Q',data,ctx+248,0x100456)
    struct.pack_into('<I',data,mods,1)
    struct.pack_into('<QIIII',data,mods+4,0x100000,0x2000,0,0,text)
    struct.pack_into('<I',data,text,len(name));data[text+4:text+4+len(name)]=name
    data[memory:memory+32]=b'PRIVATE_MEMORY_DO_NOT_DECODE_XXXX'
    return bytes(data),memory


class MetadataTest(unittest.TestCase):
    def test_only_exception_and_code_module_offset_not_paths_or_memory(self):
        data,memory=fixture()
        class Tracked(io.BytesIO):
            def read(self,n=-1):
                self.assert_read(n);return super().read(n)
            def assert_read(self,n):
                if n<0 or self.tell()+n>memory:raise AssertionError('MEMORY_PAYLOAD_READ')
        result=m.parse_stream(Tracked(data),len(data))
        self.assertEqual(result['instruction'],{'status':'MAPPED_CODE_METADATA','module':'libgfxstream_backend.so','moduleOffset':'0x456'})
        self.assertEqual(result['exceptionCode'],'0x4000000b')
        self.assertNotIn('PRIVATE_MEMORY',json.dumps(result));self.assertNotIn('/sdk/',json.dumps(result))
        self.assertFalse(result['memoryOrStackStreamsDecoded'])

    def test_bad_metadata_range_and_unbounded_module_name_fail_closed(self):
        data,_=fixture();b=bytearray(data)
        struct.pack_into('<I',b,672,999999)
        with self.assertRaises(m.InvalidMetadata):m.parse_stream(io.BytesIO(b),len(b))
        b=bytearray(data);struct.pack_into('<I',b,44+8,0xfffffff0)
        with self.assertRaises(m.InvalidMetadata):m.parse_stream(io.BytesIO(b),len(b))

    def test_arbitrary_non_module_strings_are_never_emitted(self):
        self.assertEqual(m.safe_module_name('/private/TOKEN_OR_USER_NOTE'),'<unrecognized-code-module>')

    def test_collector_copies_no_raw_dump(self):
        data,_=fixture()
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)/'crashes';root.mkdir();(root/'sample.dmp').write_bytes(data)
            output=Path(td)/'out'/'metadata.json';m.collect([root],output)
            result=json.loads(output.read_text());self.assertTrue(result['noDumpCopied'])
            self.assertEqual(list(output.parent.iterdir()),[output])
            self.assertNotIn('PRIVATE_MEMORY',output.read_text())

    def test_missing_dump_is_not_reported_as_a_diagnosis(self):
        with tempfile.TemporaryDirectory() as td:
            output=Path(td)/'metadata.json';m.collect([Path(td)],output)
            self.assertEqual(json.loads(output.read_text())['status'],'NO_MINIDUMP_FOUND')

    def test_symlink_dump_is_not_opened(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);(root/'private.bin').write_bytes(b'PRIVATE')
            (root/'linked.dmp').symlink_to(root/'private.bin')
            output=root/'metadata.json';m.collect([root],output)
            self.assertEqual(json.loads(output.read_text())['records'],[])

    def test_other_context_architecture_never_uses_amd64_register_offset(self):
        data,_=fixture();b=bytearray(data);struct.pack_into('<H',b,80,12)
        struct.pack_into('<I',b,136+164,0xffffffff)
        result=m.parse_stream(io.BytesIO(b),len(b))
        self.assertEqual(result['registerRead'],'NONE')
        self.assertEqual(result['instruction']['status'],'UNSUPPORTED_CONTEXT_ARCHITECTURE')

    def test_truncated_header_duplicate_stream_and_context_outside_file_refused(self):
        data,_=fixture()
        bad_context=bytearray(data);struct.pack_into('<I',bad_context,136+164,0xffffffff)
        for b in [data[:8],bad_context]:
            with self.assertRaises(m.InvalidMetadata):m.parse_stream(io.BytesIO(b),len(b))
        b=bytearray(data);struct.pack_into('<I',b,32+36,6)
        with self.assertRaises(m.InvalidMetadata):m.parse_stream(io.BytesIO(b),len(b))


if __name__=='__main__':unittest.main(verbosity=2)
