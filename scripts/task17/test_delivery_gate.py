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

SOURCE='fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568'
class DeliveryGate(unittest.TestCase):
    def check_gate(self, mutation=None):
        current='a'*40
        jobs=[{'name':n,'conclusion':'success'} for n in ['verify','candidate17']]
        for i,(e,b) in enumerate([('master',25),('master',26),('client',25)]):
            jobs.append({'id':i,'name':f'native17 ({e}, {b}, asset, sha)','conclusion':'success','steps':[{'name':'UI-created native baseline to27 and cold data verification','conclusion':'success'}]})
        tree=[{'path':p,'sha':p} for p in ['lib','android','third_party','test','server','pubspec.yaml','pubspec.lock']]
        data={
          '':{'private':True},
          'actions/runs/43548636228':{'head_sha':SOURCE,'status':'completed','conclusion':'success','head_branch':'fix/task17-stable-auth-queue','event':'workflow_dispatch'},
          'actions/runs/43548636228/jobs?per_page=100':{'jobs':jobs},
          'git/commits/'+SOURCE:{'tree':{'sha':'original'}},'git/commits/'+current:{'tree':{'sha':'current'}},
          'git/trees/original':{'tree':tree},'git/trees/current':{'tree':[dict(x) for x in tree]},
          'releases/123':{'draft':True,'tag_name':'task17-qa-pair-27','target_commitish':SOURCE,'assets':[]},
        }
        for rid,driver,jid,prefix,e,b in [(43583577375,'56a9b362718f48bef83eca8daf24d3e58a0431ca',132413251139,'native17_cached','master',25),(43614090740,'45aca0ce0a0eda8e7a554a6308ac5df002e94557',132505244736,'native17_cached','master',26)]:
            data['actions/runs/'+str(rid)]={'head_sha':driver,'status':'completed','event':'workflow_dispatch','head_branch':'fix/task17-stable-auth-queue'}
            data['actions/runs/'+str(rid)+'/jobs?per_page=100']={'jobs':[{'id':jid,'name':f'{prefix} ({e}, {b}, asset, sha)','conclusion':'success','steps':[{'name':'UI-created native baseline to27 and cold data verification','conclusion':'success'}]}]}
            data['git/commits/'+driver]={'tree':{'sha':'original'}}
        jobs[-1]['id']=132310281448
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
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43548636228'].update(status='in_progress'))
    def test_missing_native_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43548636228/jobs?per_page=100']['jobs'].pop())
    def test_untested_runtime_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['git/trees/current']['tree'][0].update(sha='changed'))
    def test_failed_native_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43548636228/jobs?per_page=100']['jobs'][0].update(conclusion='failure'))
    def test_failed_build_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43548636228/jobs?per_page=100']['jobs'][1].update(conclusion='failure'))
    def test_master26_failure_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43614090740/jobs?per_page=100']['jobs'][0].update(conclusion='failure'))
    def test_wrong_native_driver_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['actions/runs/43614090740'].update(head_sha='wrong'))
    def test_public_release_denied(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['releases/123'].update(draft=False))
    def test_existing_assets_not_overwritten(self):
        with self.assertRaises(AssertionError):self.check_gate(lambda d:d['releases/123'].update(assets=[{'id':1}]))

if __name__=='__main__':unittest.main()
