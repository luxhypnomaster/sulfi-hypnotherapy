"""Adversarial tests for release evidence; never use real credentials or devices."""
import copy
import hashlib
import json
import pathlib
import tempfile
import unittest

from delivery_gate import PROBE, UPGRADE, repo_endpoint, validate_receipt


class GateTest(unittest.TestCase):
    def test_repository_endpoint_has_no_trailing_slash(self):
        self.assertEqual(repo_endpoint('owner/project', ''), 'repos/owner/project')
        self.assertEqual(repo_endpoint('owner/project', 'releases/1'), 'repos/owner/project/releases/1')

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.path = self.root / 'reports/task18/proof.json'
        self.path.parent.mkdir(parents=True)
        self.value = {'source': 's', 'driverSource': 'd', 'cases': [
            {'case': c, 'status': 'PASS'} for c in sorted(PROBE)]}
        self.item = {'receipt': 'reports/task18/proof.json', 'driverSource': 'd', 'job': 'probe18'}

    def check(self, key='api35'):
        raw = (json.dumps(self.value) + '\n').encode()
        self.path.write_bytes(raw)
        self.item['receiptSHA256'] = hashlib.sha256(raw).hexdigest()
        return validate_receipt(key, self.item, 's', self.root)

    def test_complete_native_proof(self):
        self.check()

    def test_every_missing_case_rejected(self):
        original = copy.deepcopy(self.value)
        for i in range(len(PROBE)):
            self.value = copy.deepcopy(original)
            del self.value['cases'][i]
            with self.assertRaises(AssertionError):
                self.check()

    def test_cold_gate_required_for_api34(self):
        with self.assertRaises(AssertionError):
            self.check('api34')
        self.value['cases'].append({'case': 'master_actual_SIGKILL_cold_OS_recovery_preserves_request_and_source', 'status': 'PASS'})
        self.check('api34')

    def test_empty_and_partial_and_duplicate_rejected(self):
        original = copy.deepcopy(self.value)
        for cases in [[], [{'case': c, 'status': 'PARTIAL'} for c in PROBE], original['cases'] + [original['cases'][0]]]:
            self.value['cases'] = cases
            with self.assertRaises(AssertionError):
                self.check()

    def test_wrong_source_or_driver_rejected(self):
        for field in ['source', 'driverSource']:
            original = self.value[field]
            self.value[field] = 'other'
            with self.assertRaises(AssertionError):
                self.check()
            self.value[field] = original

    def test_modified_receipt_rejected(self):
        self.check()
        self.path.write_text('{}')
        with self.assertRaises(AssertionError):
            validate_receipt('api35', self.item, 's', self.root)

    def test_path_escape_rejected(self):
        self.item['receipt'] = 'reports/task18/../../other.json'
        with self.assertRaises(AssertionError):
            self.check()

    def test_master_requires_both_diary_checks(self):
        self.value.update(baseline=27, target=28, edition='master')
        self.item['job'] = 'native18 (master)'
        self.value['cases'] = [{'case': c, 'status': 'PASS'} for c in UPGRADE]
        with self.assertRaises(AssertionError):
            self.check('master_upgrade')
        self.value['cases'] += [{'case': c, 'status': 'PASS'} for c in ['ui_baseline_local_draft27', 'local_draft_after28']]
        self.check('master_upgrade')
        self.value['baseline'] = 26
        with self.assertRaises(AssertionError):
            self.check('master_upgrade')


if __name__ == '__main__':
    unittest.main()
