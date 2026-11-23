"""Local security/provenance tests. No credentials, signing, network or Android claims."""
from contextlib import contextmanager
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import urllib.request
import zipfile

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import candidate25 as c
import native25 as n


@contextmanager
def trusted(root, workflow=c.BUILD_WORKFLOW):
    env = dict(GITHUB_REPOSITORY=c.REPO, GITHUB_EVENT_NAME='workflow_dispatch',
               GITHUB_REF='refs/heads/main', GITHUB_REF_PROTECTED='true',
               GITHUB_ACTOR=c.OWNER, GITHUB_TRIGGERING_ACTOR=c.OWNER,
               GITHUB_WORKFLOW_REF=f'{c.REPO}/{workflow}@refs/heads/main',
               GITHUB_SHA='a'*40, RUNNER_TEMP=str(root), CANDIDATE25_WORKFLOW=workflow,
               CANDIDATE25_CONFIRMATION=c.BUILD_CONFIRM if workflow == c.BUILD_WORKFLOW else c.QA_CONFIRM)
    with mock.patch.dict(os.environ, env, clear=True):
        yield


class TrustAndTransport(unittest.TestCase):
    def test_all_context_checks_fail_closed_individually(self):
        with tempfile.TemporaryDirectory() as td, trusted(td):
            self.assertEqual(c.guard(), Path(td))
            for key in ['GITHUB_REPOSITORY', 'GITHUB_EVENT_NAME', 'GITHUB_REF', 'GITHUB_REF_PROTECTED',
                        'GITHUB_ACTOR', 'GITHUB_TRIGGERING_ACTOR', 'GITHUB_WORKFLOW_REF',
                        'GITHUB_SHA', 'CANDIDATE25_CONFIRMATION', 'CANDIDATE25_WORKFLOW', 'RUNNER_TEMP']:
                with self.subTest(key=key), mock.patch.dict(os.environ, {key: 'untrusted'}):
                    with self.assertRaises(c.GateError): c.guard()

    def test_error_redacts_credentials_and_signed_query(self):
        with mock.patch.dict(os.environ, {k:'secret-'+k for k in (*c.SIGNING_KEYS, 'GH_TOKEN')}, clear=True):
            msg = c.redact(' '.join(os.environ.values()) + ' https://host/file?sig=SENSITIVE&x=abc')
            self.assertNotIn('secret-', msg)
            self.assertNotIn('SENSITIVE', msg)
            proc = subprocess.CompletedProcess(['tool'], 42, '', 'permission denied secret-GH_TOKEN')
            with mock.patch.object(c.subprocess, 'run', return_value=proc):
                with self.assertRaisesRegex(c.GateError, 'COMMAND_FAILED_tool_42: permission denied') as e:
                    c.command(['tool'])
                self.assertNotIn('secret-', str(e.exception))

    def test_redirect_strips_bearer_on_host_change_only(self):
        req = urllib.request.Request('https://api.github.com/original', headers={'Authorization':'Bearer controlled-token'})
        handler = c.SafeRedirect()
        for url, expected in [('https://api.github.com/new', 'Bearer controlled-token'), ('https://blob.example/new?sig=opaque', None)]:
            got = handler.redirect_request(req, None, 302, 'Found', {}, url)
            self.assertEqual(got.get_header('Authorization'), expected)
        with self.assertRaisesRegex(c.GateError, 'NON_TLS'):
            handler.redirect_request(req, None, 302, 'Found', {}, 'http://blob.example/new')

    def test_download_refuses_unapproved_endpoint_before_token_use(self):
        with mock.patch.object(c.urllib.request, 'build_opener') as opener:
            with self.assertRaisesRegex(c.GateError, 'UNAPPROVED_API_ENDPOINT'):
                c.fetch('https://attacker.example/steal')
            opener.assert_not_called()

    def test_build_never_accepts_signing_bindings(self):
        with tempfile.TemporaryDirectory() as td:
            for key in [*c.SIGNING_KEYS, 'SULFI_SIGNING_STORE_FILE']:
                with self.subTest(key=key), mock.patch.dict(os.environ, {key:'controlled-do-not-use'}, clear=True):
                    with self.assertRaisesRegex(c.GateError, 'MUST_NOT_ENTER_BUILD'):
                        c.build(Path(td))

    def test_unsigned_overlay_only_changes_approved_debug_signing_line(self):
        original = (ROOT/'android/app/build.gradle.kts').read_bytes()
        self.assertEqual(hashlib.sha256(original).hexdigest(), c.GRADLE_PIN)
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)/'build.gradle.kts'; p.write_bytes(original)
            receipt = c.unsigned_patch(p)
            inserted = b'            signingConfig = null // trusted CI: unsigned data build; no new debug key\n'
            self.assertEqual(p.read_bytes().replace(inserted, b''), original)
            self.assertEqual(receipt['beforeSHA256'], c.GRADLE_PIN)
            with self.assertRaisesRegex(c.GateError, 'UNREVIEWED_NATIVE'):
                c.unsigned_patch(p)


class ArtifactData(unittest.TestCase):
    def fixture(self, td, *, bad=None):
        run = {'head_branch':'main', 'event':'workflow_dispatch', 'actor':{'login':c.OWNER},
               'path':c.BUILD_WORKFLOW, 'status':'completed', 'conclusion':'success', 'head_sha':'a'*40}
        if bad:run.update(bad)
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as z:z.writestr('allowed.json', '{}')
        raw=data.getvalue()
        row={'id':123, 'name':'controlled-artifact', 'expired':False, 'digest':'sha256:'+hashlib.sha256(raw).hexdigest()}
        def api(path):return run if path.endswith('/123456') else {'artifacts':[row]}
        def fetch(url, output):Path(output).write_bytes(raw)
        return run,row,raw,api,fetch

    def test_approved_data_only_archive_roundtrip(self):
        with tempfile.TemporaryDirectory() as td, trusted(td):
            _,_,_,api,fetch=self.fixture(td)
            with mock.patch.object(c,'api',side_effect=api),mock.patch.object(c,'fetch',side_effect=fetch):
                out,_=c.artifact(Path(td),123456,'controlled-artifact',['allowed.json'],'data')
                self.assertEqual((out/'allowed.json').read_text(),'{}')

    def test_rejects_non_main_untrusted_actor_workflow_or_failed_run(self):
        for bad in [{'head_branch':'feature'}, {'event':'pull_request'}, {'actor':{'login':'other'}},
                    {'path':'.github/workflows/other.yml'}, {'conclusion':'failure'}]:
            with self.subTest(bad=bad),tempfile.TemporaryDirectory() as td,trusted(td):
                _,_,_,api,fetch=self.fixture(td,bad=bad)
                with mock.patch.object(c,'api',side_effect=api),mock.patch.object(c,'fetch',side_effect=fetch) as dl:
                    with self.assertRaises(c.GateError):c.artifact(Path(td),123456,'controlled-artifact',['allowed.json'],'data')
                    dl.assert_not_called()

    def test_provider_digest_is_enforced(self):
        with tempfile.TemporaryDirectory() as td,trusted(td):
            _,row,_,api,fetch=self.fixture(td); row['digest']='sha256:'+'0'*64
            with mock.patch.object(c,'api',side_effect=api),mock.patch.object(c,'fetch',side_effect=fetch):
                with self.assertRaisesRegex(c.GateError,'PROVIDER_SHA'):
                    c.artifact(Path(td),123456,'controlled-artifact',['allowed.json'],'data')

    def test_unexpected_archive_entries_cannot_be_extracted(self):
        with tempfile.TemporaryDirectory() as td,trusted(td):
            _,row,_,api,_=self.fixture(td)
            b=io.BytesIO()
            with zipfile.ZipFile(b,'w') as z:z.writestr('../escape','x')
            raw=b.getvalue(); row['digest']='sha256:'+hashlib.sha256(raw).hexdigest()
            with mock.patch.object(c,'api',side_effect=api),mock.patch.object(c,'fetch',side_effect=lambda u,p:Path(p).write_bytes(raw)):
                with self.assertRaisesRegex(c.GateError,'CONTENTS_OR_CRC'):
                    c.artifact(Path(td),123456,'controlled-artifact',['allowed.json'],'data')
                self.assertFalse((Path(td)/'escape').exists())


class Workflows(unittest.TestCase):
    def setUp(self):
        self.paths=[ROOT/'scripts/task25/review_only'/f'sulfi-candidates25-{suffix}.yml' for suffix in ['build','verify']]
        self.ws=[yaml.safe_load(p.read_text()) for p in self.paths]

    def test_manual_owner_main_only_and_least_privilege(self):
        for w in self.ws:
            self.assertEqual(set(w['on']), {'workflow_dispatch'})
            self.assertEqual(w['permissions'], {})
            self.assertFalse(w['concurrency']['cancel-in-progress'])
            for job in w['jobs'].values():
                for clause in ["github.ref == 'refs/heads/main'", "github.ref_protected == true",
                               "github.actor == 'luxhypnomaster'", "github.triggering_actor == 'luxhypnomaster'",
                               "github.event_name == 'workflow_dispatch'", "github.repository == 'luxhypnomaster/sulfi-hypnotherapy'"]:
                    self.assertIn(clause,job['if'])
                self.assertNotIn('||',job['if'])
                self.assertNotIn('write',job['permissions'].values())
                self.assertNotIn('environment',job)

    def test_signing_environment_never_reaches_app_or_native_jobs(self):
        build,qa=self.ws
        for name,job in build['jobs'].items():
            if name not in ['credentials','sign']:self.assertNotIn('secrets.',str(job))
        sign=build['jobs']['sign']
        self.assertNotIn('appsource',str(sign))
        self.assertNotIn('flutter',str(sign))
        self.assertNotIn('gradle',str(sign))
        self.assertNotIn('secrets.',str(qa))
        for name in ['credentials','sign']:
            secretsteps=[s for s in build['jobs'][name]['steps'] if 'secrets.' in str(s)]
            self.assertEqual(len(secretsteps),1)
            self.assertEqual(set(secretsteps[0]['env']),set(c.SIGNING_KEYS))
            self.assertNotIn('GH_TOKEN',secretsteps[0]['env'])

    def test_all_actions_and_source_checkouts_are_pinned(self):
        for w in self.ws:
            for job in w['jobs'].values():
                for step in job['steps']:
                    if 'uses' in step:
                        self.assertRegex(step['uses'],r'^[A-Za-z0-9-]+/[A-Za-z0-9-]+@[0-9a-f]{40}$')
                    if step.get('with',{}).get('path')=='appsource':
                        self.assertEqual(step['with']['ref'],c.SOURCE)
                    if 'checkout@' in step.get('uses',''):
                        self.assertFalse(step['with']['persist-credentials'])

    def test_trusted_helper_pins_match_current_bytes(self):
        for w in self.ws:
            for job in w['jobs'].values():
                for step in job['steps']:
                    if 'Verify reviewed trusted helper' in step.get('name',''):
                        self.assertIn(c.digest(ROOT/'scripts/task25/candidate25.py'),step['run'])
                        if 'native25.py' in step['run']:self.assertIn(c.digest(ROOT/'scripts/task25/native25.py'),step['run'])

    def test_embedded_python_compiles_and_no_key_generation_or_deploy(self):
        for p,w in zip(self.paths,self.ws):
            for forbidden in ['pull_request_target','clasp ', 'gh release ', 'generatekey', '-genkey', 'keytool -import', 'git push']:
                self.assertNotIn(forbidden,p.read_text())
            for job in w['jobs'].values():
                for step in job['steps']:
                    run=step.get('run','')
                    if run.startswith("python3 - <<'PYCODE'"):
                        lines=run.splitlines();self.assertEqual(lines[-1],'PYCODE')
                        compile('\n'.join(lines[1:-1]),'trusted-inline25','exec')
        for forbidden in ['-genkey','generate_key','keytool -import']:
            self.assertNotIn(forbidden,(ROOT/'scripts/task25/candidate25.py').read_text())

    def test_native_and_delivery_require_both_editions_and_both_apis(self):
        qa=self.ws[1]
        for api in [34,36]:
            j=qa['jobs']['native'+str(api)]
            self.assertEqual(j['strategy']['matrix']['edition'],['master','client'])
            emulator=next(s for s in j['steps'] if 'emulator-runner@' in s.get('uses',''))
            self.assertEqual(emulator['env']['TASK17_EMULATOR_PIN'],'37.2.12')
            self.assertEqual(emulator['with']['api-level'],api)
        self.assertEqual(qa['jobs']['native36']['needs'],'native34')
        self.assertEqual(qa['jobs']['delivery']['needs'],['native34','native36'])
        self.assertNotIn('continue-on-error',str(qa))

    def test_supplement_is_insert_only_and_cannot_reset_original_database(self):
        for required in ['EMULATOR_ONLY','APP_OWNED_EXISTING_DB_ONLY','SCHEMA9_REQUIRED','NO_UNRELATED_SETTINGS',
                         'NO_UNRELATED_PUBLIC_CACHE','NO_OTHER_TABLES','insertOrThrow','CONTROLLED_NATIVE25_SUPPLEMENT_NOT_GOOGLE']:
            self.assertIn(required,n.FIXTURE_JAVA)
        for forbidden in ['CONFLICT_REPLACE','deleteDatabase','setVersion(', 'CREATE TABLE', 'DROP TABLE', 'DELETE FROM']:
            self.assertNotIn(forbidden,n.FIXTURE_JAVA)


if __name__=='__main__':unittest.main(verbosity=2)
