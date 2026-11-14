import contextlib,io,json,pathlib,sys,tempfile,unittest
from monitor_emulator import monitor
class Monitor(unittest.TestCase):
 def exercise(self,code):
  with tempfile.TemporaryDirectory() as td,contextlib.redirect_stdout(io.StringIO()):
   rc=monitor([sys.executable,'-c',code],td);files=list(pathlib.Path(td).glob('EMULATOR_FORENSIC_*.json'));self.assertEqual(len(files),1);return rc,json.loads(files[0].read_text())
 def test_exit_code(self):
  rc,v=self.exercise('raise SystemExit(7)');self.assertEqual(rc,7);self.assertEqual(v['exitCode'],7);self.assertIsNone(v['signal'])
 def test_real_signal(self):
  rc,v=self.exercise('import os,signal;os.kill(os.getpid(),signal.SIGTERM)');self.assertEqual(rc,143);self.assertEqual(v['signal'],'SIGTERM');self.assertEqual(v['wrapperReceivedSignals'],[])
 def test_success(self):
  rc,v=self.exercise('pass');self.assertEqual(rc,0);self.assertEqual(v['exitCode'],0);self.assertIn('before',v);self.assertNotIn('command',v)
if __name__=='__main__':unittest.main()
