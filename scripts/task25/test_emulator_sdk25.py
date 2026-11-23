"""Synthetic SDK integrity/security tests, never a native Android PASS."""
import io
import json
import os
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest import mock
import zipfile

import emulator_sdk25 as s
from candidate25 import GateError, SIGNING_KEYS


def archive(extra=(), revision=s.VERSION):
    b=io.BytesIO()
    with zipfile.ZipFile(b,'w') as z:
        z.writestr('emulator/emulator','controlled SDK fixture, not executable')
        z.writestr('emulator/source.properties',f'Pkg.Revision={revision}\nPkg.BuildId={s.BUILD}\n')
        for name,value in extra:z.writestr(name,value)
    b.seek(0)
    return zipfile.ZipFile(b)


class SDKTests(unittest.TestCase):
    def test_reviewed_metadata_and_minimal_archive(self):
        with archive() as z:self.assertEqual(len(s.members_checked(z)),2)
        self.assertEqual(s.URL,'https://dl.google.com/android/repository/emulator-linux_x64-16970787.zip')
        self.assertEqual(s.SHA256,'a4405349d8a9c52136ab7861e5331dc40e85574bd91cb8889a298a2ff4c52e26')

    def test_archive_traversal_absolute_backslash_and_duplicates_refused(self):
        for name in ['emulator/../../private','/emulator/private','emulator\\escape','other/file','emulator/emulator']:
            with self.subTest(name=name), archive([(name,'bad')]) as z:
                with self.assertRaises(GateError):s.members_checked(z)

    def test_symlink_member_refused_before_extraction(self):
        info=zipfile.ZipInfo('emulator/lib64/link');info.external_attr=0o120777<<16
        with archive([(info,'../../outside')]) as z:
            with self.assertRaises(GateError):s.members_checked(z)

    def test_old_or_other_sdk_revision_is_not_accepted(self):
        with archive(revision='37.2.12') as z:
            with self.assertRaisesRegex(GateError,'VERSION_MISMATCH'):s.members_checked(z)

    def test_bad_archive_fails_without_mutating_any_sdk(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'bad.zip';p.write_bytes(b'untrusted')
            with self.assertRaises(GateError):s.verify_archive(p)
            self.assertEqual(p.read_bytes(),b'untrusted')

    def test_synthetic_correct_size_but_wrong_hash_refused(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'bad.zip';p.write_bytes(b'untrusted')
            with mock.patch.object(s,'SIZE',p.stat().st_size):
                with self.assertRaisesRegex(GateError,'HASH_MISMATCH'):s.verify_archive(p)

    def test_signing_bindings_refused_before_download_or_sdk_mutation(self):
        for key in SIGNING_KEYS:
            with mock.patch.object(s,'guard',return_value=Path('/tmp')),mock.patch.dict(os.environ,{'CANDIDATE25_WORKFLOW':s.QA_WORKFLOW,key:'controlled-secret'},clear=True),mock.patch.object(s.urllib.request,'urlopen') as request:
                with self.assertRaisesRegex(GateError,'SIGNING_BINDINGS_FORBIDDEN'):s.install()
                request.assert_not_called()

    def test_guard_refusal_precedes_all_filesystem_mutation(self):
        with mock.patch.object(s,'guard',side_effect=GateError('UNTRUSTED')),mock.patch.object(s.urllib.request,'urlopen') as request:
            with self.assertRaisesRegex(GateError,'UNTRUSTED'):s.install()
            request.assert_not_called()

    def receipt(self):
        return {'status':'PASS_OFFICIAL_STABLE_EMULATOR_PIN','version':s.VERSION,'archiveSha256':s.SHA256,'archiveSha1':s.SHA1,'archiveBytes':s.SIZE,'validatedHeadlessVersion':True}

    def test_readiness_refuses_old_spoof_missing_or_symlink_marker(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'ready';self.assertFalse(s.ready_valid(p))
            v=self.receipt();p.write_text(json.dumps(v));self.assertTrue(s.ready_valid(p))
            for key in ['status','version','archiveSha256','archiveSha1','archiveBytes','validatedHeadlessVersion']:
                broken={**v,key:None};p.write_text(json.dumps(broken));self.assertFalse(s.ready_valid(p))
            p.write_text(json.dumps(v));link=Path(td)/'link';link.symlink_to(p);self.assertFalse(s.ready_valid(link))

    def test_kernel_output_only_monitored_process_module_relative_ip(self):
        text='qemu-system-x86[42]: segfault at 0 ip 00001010 sp 00002000 error 4 in libgfxstream_backend.so[1000+100]\nother[42]: segfault PRIVATE\nqemu-system-x86[99]: segfault at PRIVATE in libOTHER.so[1000+100]\n'
        rows=s.kernel_fault_records(text,{42})
        self.assertEqual(rows,[{'pid':42,'status':'MONITORED_HOST_SEGFAULT_CODE_MODULE','module':'libgfxstream_backend.so','instructionOffset':'0x10'}])
        output=json.dumps(rows);self.assertNotIn('PRIVATE',output);self.assertNotIn('00002000',output);self.assertNotIn('libOTHER',output)

    def test_non_module_strings_or_absolute_paths_not_published(self):
        rows=s.kernel_fault_records('qemu-system-x86[42]: segfault at SECRET in /private/USER_NOTE[1000+100]',{42})
        self.assertEqual(rows,[{'pid':42,'status':'MONITORED_HOST_SEGFAULT_MODULE_UNAVAILABLE'}])

    def test_healthy_run_does_not_read_kernel_log(self):
        with tempfile.TemporaryDirectory() as td,mock.patch.object(s,'qa_guard',return_value=Path(td)),mock.patch.dict(os.environ,{'GITHUB_WORKSPACE':td}),mock.patch.object(s.subprocess,'run') as command:
            s.collect_kernel();command.assert_not_called()
            v=json.loads((Path(td)/'task25-native-evidence/forensics/KERNEL_MODULE_METADATA_25.json').read_text())
            self.assertFalse(v['rawKernelLogPublished']);self.assertEqual(v['status'],'NO_MONITORED_HOST_SIGSEGV')

    def test_sdk_wrong_binary_version_restores_previous_disposable_sdk(self):
        self.installer(False)

    def test_sdk_success_keeps_only_verified_new_sdk_and_public_receipt(self):
        self.installer(True)

    def installer(self, success):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);sdk=root/'android';old=sdk/'emulator';old.mkdir(parents=True)
            (old/'previous-sdk').write_bytes(b'PREVIOUS_VERIFIED_SDK')
            z=archive();data=z.fp.getvalue();z.close()
            def fetch(*args,**kw):return io.BytesIO(data)
            result=subprocess.CompletedProcess([],0,'Android emulator version '+(s.VERSION if success else '37.2.12')+' (build_id)\n','')
            with mock.patch.object(s,'qa_guard',return_value=root),mock.patch.dict(os.environ,{'ANDROID_HOME':str(sdk),'TASK17_EMULATOR_PIN':s.VERSION}),mock.patch.object(s.urllib.request,'urlopen',side_effect=fetch),mock.patch.object(s,'verify_archive'),mock.patch.object(s.subprocess,'run',return_value=result):
                if success:
                    receipt=s.install();self.assertTrue(s.receipt_valid(receipt))
                    self.assertTrue((old/'emulator').exists());self.assertFalse((old/'previous-sdk').exists())
                    self.assertFalse((root/'task25-previous-disposable-sdk').exists())
                    self.assertEqual(json.loads((root/'task25-native-evidence/SDK_PIN_25.json').read_text()),receipt)
                else:
                    with self.assertRaisesRegex(GateError,'BINARY_VERSION_MISMATCH'):s.install()
                    self.assertEqual((old/'previous-sdk').read_bytes(),b'PREVIOUS_VERIFIED_SDK')
                    self.assertFalse((old/'emulator').exists())

    def test_kernel_permission_denial_does_not_print_stderr_or_private_lines(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);f=root/'.task17-forensics';f.mkdir()
            (f/'EMULATOR_FORENSIC_1.json').write_text(json.dumps({'avdLaunch':True,'signal':'SIGSEGV','childPid':42}))
            result=subprocess.CompletedProcess([],1,'SECRET_KERNEL_LINE','PRIVATE_PERMISSION_ERROR')
            with mock.patch.object(s,'qa_guard',return_value=root),mock.patch.dict(os.environ,{'GITHUB_WORKSPACE':td}),mock.patch.object(s.subprocess,'run',return_value=result):s.collect_kernel()
            text=(root/'task25-native-evidence/forensics/KERNEL_MODULE_METADATA_25.json').read_text()
            self.assertEqual(json.loads(text)['status'],'KERNEL_METADATA_UNAVAILABLE')
            self.assertNotIn('SECRET',text);self.assertNotIn('PRIVATE_PERMISSION',text)


if __name__=='__main__':unittest.main()
