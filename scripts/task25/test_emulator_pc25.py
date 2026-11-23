"""Host diagnosis safety tests. These never claim a native preservation PASS."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import emulator_pc25 as p
from candidate25 import GateError, QA_WORKFLOW
from test_candidate25 import trusted


class ModuleTest(unittest.TestCase):
    def test_relative_code_offset_only_no_address_path_stack_or_data(self):
        got=p.instruction_module('7000-9000 r-xp 00001000 08:01 99 /private/sdk/lib64/libOpenglRender.so',0x7123)
        self.assertEqual(got,{'status':'EXECUTABLE_INSTRUCTION_MODULE','module':'libOpenglRender.so','instructionFileOffset':'0x1123'})
        self.assertNotIn('private',json.dumps(got));self.assertNotIn('7000',json.dumps(got))

    def test_no_nonexecutable_data_or_unknown_path_names_published(self):
        for maps in ['7000-9000 rw-p 0000 08:01 99 /private/secret',
                     '7000-9000 r-xp 0000 08:01 99 /private/secret',
                     'malformed']:
            got=p.instruction_module(maps,0x7123)
            self.assertNotIn('module',got)
            self.assertNotIn('secret',json.dumps(got))

    def test_qemu_and_public_runtime_names_allowed_but_no_mapped_base(self):
        for name in ['qemu-system-x86_64','libc.so.6','libLLVM.so.19','ld-linux-x86-64.so.2','dash']:
            self.assertEqual(p.instruction_module('7000-9000 r-xp 0000 08:01 99 /sdk/'+name,0x7001)['module'],name)

    def test_script_has_no_stack_memory_dump_or_environment_commands(self):
        for forbidden in ['bt full','read_memory','info registers','info locals','info args','generate-core-file','environ[']:
            self.assertNotIn(forbidden,p.GDB_SCRIPT.replace("os.environ['TASK25_PC_HELPER_DIRECTORY']",'FIXED').replace("os.environ['TASK25_PC_RESULT']",'FIXED'))
        self.assertIn("gdb.parse_and_eval('$pc')",p.GDB_SCRIPT)
        self.assertIn('handle SIGSEGV stop print pass',p.GDB_SCRIPT)
        self.assertNotIn('handle SIGSEGV stop noprint',p.GDB_SCRIPT)
        self.assertIn('set logging file /dev/null',p.GDB_SCRIPT)
        self.assertIn('set logging redirect on',p.GDB_SCRIPT)
        self.assertIn("gdb.parse_and_eval('$_exitsignal')",p.GDB_SCRIPT)
        self.assertIn("gdb.execute(command, to_string=True)",p.GDB_SCRIPT)


class LifecycleTest(unittest.TestCase):
    def test_real_control_program_passes_usr_signals_then_actual_sigsegv_no_shell(self):
        with tempfile.TemporaryDirectory() as td:
            f=Path(td)/'control.py';f.write_text(p.CONTROL_SCRIPT)
            run=subprocess.run(['/usr/bin/python3',str(f)],capture_output=True,timeout=10)
            self.assertEqual(run.returncode,-11)
            self.assertEqual(run.stdout,b'');self.assertEqual(run.stderr,b'')

    def test_default_off_never_launches_or_changes_sdk(self):
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.object(p.subprocess,'run') as run,mock.patch.object(p.shutil,'which') as which:
            self.assertIsNone(p.prepare());run.assert_not_called();which.assert_not_called()

    def test_untrusted_context_rejected_even_if_flag_on(self):
        with mock.patch.dict(os.environ,{'TASK25_PC_DIAGNOSTIC':'true'},clear=True):
            with self.assertRaises(GateError):p.prepare()

    def test_unavailable_gdb_stops_before_any_emulator_action(self):
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.dict(os.environ,{'TASK25_PC_DIAGNOSTIC':'true'}),mock.patch.object(p.shutil,'which',return_value=None),mock.patch.object(p.subprocess,'run') as run:
            with self.assertRaisesRegex(GateError,'GDB_UNAVAILABLE'):p.host_preflight()
            run.assert_not_called()

    def test_failed_control_never_wraps_android_binary(self):
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.dict(os.environ,{'TASK25_PC_DIAGNOSTIC':'true'}),mock.patch.object(p.shutil,'which',return_value='/usr/bin/gdb'):
            def fake(*args,**kwargs):
                self.assertNotIn('-c',args[0])
                self.assertEqual(Path(args[0][-1]).read_text(),p.CONTROL_SCRIPT)
                Path(kwargs['env']['TASK25_PC_RESULT']).write_text(json.dumps({'terminatedWithSIGSEGV':False,'signals':[]}))
                return subprocess.CompletedProcess(args,1)
            with mock.patch.object(p.subprocess,'run',side_effect=fake):
                with self.assertRaisesRegex(GateError,'PC_CONTROL_FAILED'):p.host_preflight()

    def test_passing_control_wraps_exact_disposable_binary_only(self):
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.dict(os.environ,{'TASK25_PC_DIAGNOSTIC':'true','ANDROID_HOME':td+'/sdk'}),mock.patch.object(p.shutil,'which',return_value='/usr/bin/gdb'),mock.patch.object(p,'fingerprint',return_value='a'*64):
            binary=Path(td)/'sdk/emulator/emulator.task17-real';binary.parent.mkdir(parents=True);binary.write_bytes(b'EXACT_VERIFIED_SDK_BYTES')
            def fake(*args,**kwargs):
                Path(kwargs['env']['TASK25_PC_RESULT']).write_text(json.dumps({'terminatedWithSIGSEGV':True,'signals':[{'status':'EXECUTABLE_INSTRUCTION_MODULE'}]}))
                return subprocess.CompletedProcess(args,255)
            with mock.patch.object(p.subprocess,'run',side_effect=fake):p.host_preflight()
            p.prepare()
            self.assertEqual(binary.with_name('emulator.task25-pc-target').read_bytes(),b'EXACT_VERIFIED_SDK_BYTES')
            self.assertIn("'--return-child-result'",binary.read_text())
            compile(binary.read_text(),str(binary),'exec')
            setup=json.loads((Path(td)/'task25-native-evidence/forensics/PC_DIAGNOSTIC_SETUP_25.json').read_text())
            self.assertFalse(setup['signingOrDeliveryEnabled'])

    def test_missing_control_receipt_cannot_wrap_sdk(self):
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.dict(os.environ,{'TASK25_PC_DIAGNOSTIC':'true'}),mock.patch.object(p.shutil,'which',return_value='/usr/bin/gdb'):
            with self.assertRaisesRegex(GateError,'CONTROL_RECEIPT_REQUIRED'):p.prepare()

    def test_control_bound_to_actual_gdb_and_script_bytes(self):
        with mock.patch.object(p,'fingerprint',return_value='a'*64):
            import hashlib
            receipt={'status':'PASS_REAL_PC_HOST_CONTROL','gdbSHA256':'a'*64,'scriptSHA256':hashlib.sha256(p.GDB_SCRIPT.encode()).hexdigest()}
            self.assertTrue(p.control_valid(receipt,'unused'))
            for key in receipt:
                self.assertFalse(p.control_valid(dict(receipt,**{key:'wrong'}),'unused'))
