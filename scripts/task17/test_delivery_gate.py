"""Offline negative gates. Controlled GitHub responses, never real authorization."""
import contextlib
import io
import json
import os
import pathlib
import runpy
import tempfile
import unittest
from unittest.mock import patch

SOURCE='85ff50736c6be28bda55cf759f232d8347f3ad3e'
class DeliveryGate(unittest.TestCase):
    def check_gate(self, mutation=None):
        current='a'*40
        jobs=[{'name':n,'conclusion':'success'} for n in ['verify','candidate17']]
        for i,(e,b) in enumerate([('master',25),('master',26),('client',25)]):
            jobs.append({'id':i,'name':f'native17_cached ({e}, {b}, asset, sha)','conclusion':'success','steps':[{'name':'UI-created native baseline to27 and cold data verification','conclusion':'success'}]})
        tree=[{'path':p,'sha':p} for p in ['lib','android','third_party','test','server','pubspec.yaml','pubspec.lock']]
        data={
          '':{'private':True},
          'actions/runs/43515852713':{'head_sha':SOURCE,'status':'completed','conclusion':'success','head_branch':'fix/task17-stable-auth-queue','event':'workflow_dispatch'},
          'actions/runs/43515852713/jobs?per_page=100':{'jobs':jobs[:2]},
          'actions/runs/43546562439':{'head_sha':'4a84759966068183cbfc5908c55e3c5a0b8b3162','status':'completed','conclusion':'success','head_branch':'fix/task17-stable-auth-queue','event':'workflow_dispatch'},
          'actions/runs/43546562439/jobs?per_page=100':{'jobs':jobs[2:]},
          'git/commits/4a84759966068183cbfc5908c55e3c5a0b8b3162':{'tree':{'sha':'original'}},
          'git/commits/'+SOURCE:{'tree':{'sha':'original'}},'git/commits/'+current:{'tree':{'sha':'current'}},
          'git/trees/original':{'tree':tree},'git/trees/current':{'tree':[dict(x) for x in tree]},
          'releases/123':{'draft':True,'tag_name':'task17-qa-pair-27','target_commitish':SOURCE,'assets':[]},
        }
        if mutation:mutation(data)
        calls=[]
        def response(args):
            self.assertEqual(args[:2],['gh','api']);self.assertFalse(args[2].endswith('/'), 'GitHub repository API rejects a trailing slash');calls.append(args[2])
            return json.dumps(data[args[2].removeprefix('repos/luxhypnomaster/sulfi-hypnotherapy').lstrip('/')]).encode()
        with tempfile.TemporaryDirectory() as td:
            p=pathlib.Path(td)/'task17-apks';p.mkdir();(p/'APK_PAIR_17.json').write_text(json.dumps({'source':SOURCE,'ownerQA':'NOT_RUN'}))
            env={'GITHUB_SHA':current,'GITHUB_REF':'refs/heads/fix/task17-stable-auth-queue','GITHUB_EVENT_NAME':'workflow_dispatch','GITHUB_REPOSITORY':'luxhypnomaster/sulfi-hypnotherapy','RUNNER_TEMP':td,'TASK17_RELEASE_ID':'123'}
            with patch.dict(os.environ,env),patch('subprocess.check_output',response),contextlib.redirect_stdout(io.StringIO()):
                runpy.run_path(str(pathlib.Path(__file__).with_name('delivery_gate.py')))
        self.assertTrue(calls)
    def test_complete_controlled_gate(self):self.check_gate()
    def test_public_repo_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d[''].update(private=False))
    def test_pending_ci_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43546562439'].update(status='in_progress'))
    def test_missing_native_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43546562439/jobs?per_page=100']['jobs'].pop())
    def test_untested_runtime_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['git/trees/current']['tree'][0].update(sha='changed'))
    def test_failed_native_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43546562439/jobs?per_page=100']['jobs'][0].update(conclusion='failure'))
    def test_failed_build_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43515852713/jobs?per_page=100']['jobs'][1].update(conclusion='failure'))
    def test_public_release_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['releases/123'].update(draft=False))
    def test_existing_assets_not_overwritten(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['releases/123'].update(assets=[{'id':1}]))

if __name__=='__main__':unittest.main()
