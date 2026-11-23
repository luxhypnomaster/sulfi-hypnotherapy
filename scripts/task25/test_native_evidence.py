"""Reject real previously failed/incomplete native artifacts; no invented PASS."""
import copy
import json
from pathlib import Path
import unittest

from verify_native_evidence import inspect, validate

ROOT = Path(__file__).resolve().parents[2]


class ActualFailedArtifactTest(unittest.TestCase):
    def setUp(self):
        base=ROOT/'reports/task25/candidate29/native_attempt1'
        self.client=json.loads((base/'client-NATIVE_UPGRADE_25.json').read_text())
        self.master=json.loads((base/'master-NATIVE_UPGRADE_25.json').read_text())
        self.driver=self.client['driverMainSHA']

    def test_real_client_update_pass_is_insufficient_when_ui_and_cold_are_incomplete(self):
        result=inspect(self.client,self.driver)
        self.assertEqual(result['status'],'BLOCKED')
        self.assertIn('ALL_CASES_PASS',result['errors'])
        self.assertIn('COMPLETE_UNIQUE_CASES',result['errors'])
        self.assertIn('ACTUAL29_coldCandidate',result['errors'])
        self.assertNotIn('SQLITE_INTEGRITY_afterCandidate',result['errors'])

    def test_cancelled_real_master_baseline_cannot_count_as_upgrade(self):
        result=inspect(self.master,self.driver)
        self.assertEqual(result['status'],'BLOCKED')
        self.assertIn('ACTUAL_BASELINE28',result['errors'])
        self.assertIn('ACTUAL29_afterCandidate',result['errors'])

    def test_two_api34_reports_never_satisfy_four_gate_delivery(self):
        result=validate([self.client,self.master],self.driver)
        self.assertEqual(result['status'],'BLOCKED_NATIVE_DELIVERY')
        self.assertFalse(result['completeFourGates'])
        self.assertEqual(result['ownerPhone'],'NOT_RUN')
        self.assertEqual(result['realGoogle'],'NOT_RUN')

    def test_tampered_source_or_fake_owner_pass_is_rejected(self):
        report=copy.deepcopy(self.client);report['applicationSourceSHA']='f'*40;report['ownerPhone']='PASS'
        result=inspect(report,self.driver)
        self.assertIn('APPLICATION_SOURCE',result['errors'])
        self.assertIn('NO_OWNER_OR_GOOGLE_PASS_CLAIM',result['errors'])

    def test_actual_completed_client34_preserves_existing_revision_rows_too(self):
        p=ROOT/'reports/task25/candidate29/native_attempt4/client-NATIVE_UPGRADE_25.json'
        report=json.loads(p.read_text())
        self.assertGreaterEqual(len(report['inventories']['beforeBaseline']['rows']['content_revisions']),3)
        result=inspect(report,report['driverMainSHA'])
        self.assertEqual(result['status'],'PASS_CONTROLLED_NATIVE',result['errors'])

    def test_native_pass_labels_cannot_hide_a_lost_revision(self):
        p=ROOT/'reports/task25/candidate29/native_attempt4/client-NATIVE_UPGRADE_25.json'
        report=json.loads(p.read_text())
        report['inventories']['afterCandidate']['rows']['content_revisions'].pop(0)
        result=inspect(report,report['driverMainSHA'])
        self.assertEqual(result['status'],'BLOCKED')
        self.assertIn('EXACT_OLD_ROWS_afterCandidate_content_revisions',result['errors'])

    def test_actual_successful_diagnostic_master_cannot_be_relabelled_as_full_observed_gate(self):
        p=ROOT/'reports/task25/candidate29/continuation_sdk37310/run12/native25-api35-master-45214392456/task25-native-evidence/NATIVE_UPGRADE_25.json'
        report=json.loads(p.read_text())
        self.assertEqual(inspect(report,report['driverMainSHA'])['status'],'PASS_CONTROLLED_NATIVE')
        result=inspect(report,report['driverMainSHA'],current_sdk=True)
        self.assertIn('CLEAN_BOUND_HOST_OBSERVER_PROOF',result['errors'])

    def test_full_proof_rejects_restart_signal_missing_or_unbound_script(self):
        from emulator_pc25 import GDB_SCRIPT
        import hashlib
        p=ROOT/'reports/task25/candidate29/continuation_sdk37310/run12/native25-api35-master-45214392456/task25-native-evidence/NATIVE_UPGRADE_25.json'
        report=json.loads(p.read_text())
        proof={'status':'PASS_CLEAN_OBSERVED_QEMU_EXIT','avdLaunchCount':1,'hostExitCode':0,
               'hostSIGSEGVCount':0,'restarts':0,'signalPolicy':'PASS_ORIGINAL_SIGNALS',
               'selftest':'PASS_REAL_PC_HOST_CONTROL','scope':'HOST_OBSERVED_CONTROLLED_ANDROID_NOT_PHYSICAL',
               'observerScriptSHA256':hashlib.sha256(GDB_SCRIPT.encode()).hexdigest()}
        report['hostObserver']=proof
        self.assertNotIn('CLEAN_BOUND_HOST_OBSERVER_PROOF',inspect(report,report['driverMainSHA'],current_sdk=True)['errors'])
        for key in proof:
            report['hostObserver']=dict(proof,**{key:'UNTRUSTED_OR_MISSING'})
            self.assertIn('CLEAN_BOUND_HOST_OBSERVER_PROOF',inspect(report,report['driverMainSHA'],current_sdk=True)['errors'])


if __name__=='__main__':unittest.main(verbosity=2)
