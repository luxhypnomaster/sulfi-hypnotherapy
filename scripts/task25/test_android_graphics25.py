"""Official launch-request boundary tests. No fake runtime renderer/phone PASS."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import android_graphics25 as g
from candidate25 import GateError,IDS,QA_WORKFLOW
from test_candidate25 import trusted


class OfficialLaunchTest(unittest.TestCase):
    def fake(self, *, qemu='1',ack='Status: ok',versions=None):
        calls=[];codes=iter(versions or [28,28,29,29])
        def adb(*args,**kwargs):
            calls.append((args,kwargs))
            if args==('shell','getprop','ro.kernel.qemu'):return qemu
            if args[:4]==('shell','am','start','-W'):return ack
            if args[:3]==('shell','dumpsys','package'):return 'versionCode='+str(next(codes))
            return b'UNCHANGED_BINARY'
        return adb,calls

    def test_default_off_does_not_query_or_change_any_command(self):
        original,calls=self.fake()
        with mock.patch.dict(os.environ,{},clear=True):
            self.assertIs(g.observed_software_adb(original,IDS['master'],Path('/unused')),original)
        self.assertEqual(calls,[])

    def test_untrusted_or_physical_device_is_rejected_before_launch(self):
        original,calls=self.fake()
        with mock.patch.dict(os.environ,{'TASK25_SOFTWARE_GRAPHICS':'true'},clear=True):
            with self.assertRaises(GateError):g.observed_software_adb(original,IDS['master'],Path('/unused'))
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.dict(os.environ,{'TASK25_SOFTWARE_GRAPHICS':'true'}):
            original,calls=self.fake(qemu='0')
            with self.assertRaisesRegex(GateError,'DISPOSABLE_EMULATOR_ONLY'):
                g.observed_software_adb(original,IDS['master'],Path(td)/'task25-native-evidence')
            self.assertEqual(len(calls),1)

    def test_exact_component_only_single_launch_with_official_flags_and_honest_receipt(self):
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.dict(os.environ,{'TASK25_SOFTWARE_GRAPHICS':'true'}):
            original,calls=self.fake();package=IDS['client']
            adb=g.observed_software_adb(original,package,Path(td)/'task25-native-evidence')
            exact=('shell','am','start','-W','-n',package+'/ru.sulfi.sulfi_hypnotherapy.MainActivity')
            for _ in range(4):self.assertEqual(adb(*exact),'Status: ok')
            launches=[args for args,kwargs in calls if args[:4]==('shell','am','start','-W')]
            self.assertEqual(launches,[exact+g.FLAGS]*4)
            self.assertEqual(adb('exec-out','run-as',package,'tar',binary=True),b'UNCHANGED_BINARY')
            self.assertEqual(calls[-1],(('exec-out','run-as',package,'tar'),{'binary':True}))
            proof=g.request_proof(td,package)
            self.assertEqual(proof['engineStateReadback'],'NOT_READ_BACK_NO_BACKEND_CLAIM')
            self.assertFalse(proof['APKChanged'])

    def test_unacknowledged_launch_never_gets_a_success_receipt(self):
        with tempfile.TemporaryDirectory() as td,trusted(td,QA_WORKFLOW),mock.patch.dict(os.environ,{'TASK25_SOFTWARE_GRAPHICS':'true'}):
            original,calls=self.fake(ack='Error type 3')
            adb=g.observed_software_adb(original,IDS['master'],Path(td)/'task25-native-evidence')
            with self.assertRaisesRegex(GateError,'NOT_ACKNOWLEDGED'):
                adb('shell','am','start','-W','-n',IDS['master']+'/ru.sulfi.sulfi_hypnotherapy.MainActivity')
            self.assertEqual(len(calls),2)
            self.assertFalse((Path(td)/'task25-native-evidence'/g.RECEIPT).exists())

    def test_proof_cannot_claim_actual_backend_or_omit_old_new_cold_launches(self):
        package=IDS['master']
        proof={'mode':g.MODE,'package':package,'engineStateReadback':g.READBACK,'APKChanged':False,
               'originalUIAndDataChecksRetained':True,
               'launches':[{'versionCode':v,'flags':list(g.FLAGS),'amStartAcknowledged':True} for v in [28,28,29,29]]}
        self.assertTrue(g.valid_proof(proof,package))
        for key,bad in [('engineStateReadback','PASS'),('APKChanged',True),('package',IDS['client'])]:
            self.assertFalse(g.valid_proof(dict(proof,**{key:bad}),package))
        bad=copy.deepcopy(proof);bad['launches'].pop();self.assertFalse(g.valid_proof(bad,package))
        bad=copy.deepcopy(proof);bad['launches'][0]['flags']=[];self.assertFalse(g.valid_proof(bad,package))
