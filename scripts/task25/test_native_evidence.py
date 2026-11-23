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


if __name__=='__main__':unittest.main(verbosity=2)
