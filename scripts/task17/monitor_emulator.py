"""Record actual child termination and host resource evidence, never guest memory."""
import json,os,pathlib,signal,subprocess,sys,time,re

def counters():
 out={}
 for name in ['memory.events','memory.current','memory.max','memory.peak']:
  try:
   groups=pathlib.Path('/proc/self/cgroup').read_text().splitlines();leaf=next((l.split('::',1)[1] for l in groups if l.startswith('0::')),'/')
   p=pathlib.Path('/sys/fs/cgroup')/leaf.lstrip('/')/name
   if p.exists():out[name]=p.read_text().strip()
  except OSError:pass
 try:
  for line in pathlib.Path('/proc/meminfo').read_text().splitlines():
   if line.startswith('MemAvailable:'):out['MemAvailable']=line.split(':',1)[1].strip()
 except OSError:pass
 return out

def monitor(command,folder):
 folder=pathlib.Path(folder);folder.mkdir(parents=True,exist_ok=True)
 before=counters();started=time.time();child=subprocess.Popen(command)
 requested=[]
 def forward(sig,frame):
  requested.append(signal.Signals(sig).name)
  if child.poll() is None:child.send_signal(sig)
 for sig in [signal.SIGTERM,signal.SIGINT]:signal.signal(sig,forward)
 samples=[]
 while child.poll() is None:
  if len(samples)<3600:
   sample={'seconds':round(time.time()-started,2),'host':counters()}
   try:sample['childStatus']=[l for l in pathlib.Path('/proc/'+str(child.pid)+'/status').read_text().splitlines() if l.startswith(('Name:','State:','VmRSS:','VmHWM:'))]
   except OSError:pass
   samples.append(sample)
  time.sleep(1)
 code=child.wait()
 result={'childPid':child.pid,'observedChildNames':sorted({l for v in samples for l in v.get('childStatus',[]) if l.startswith('Name:')}),'sampleCount':len(samples),'schema':1,'avdLaunch':'-avd' in command,'exitCode':code,'signal':signal.Signals(-code).name if code<0 else None,'wrapperReceivedSignals':requested,'before':before,'after':counters(),'durationSeconds':round(time.time()-started,2),'samples':samples}
 p=folder/('EMULATOR_FORENSIC_'+str(os.getpid())+'.json');p.write_text(json.dumps(result,indent=2)+'\n')
 # Terminal proof emitted immediately, even when adb and the native driver die.
 print('EMULATOR_TERMINATION='+json.dumps({k:v for k,v in result.items() if k!='samples'}),flush=True)
 return code if code>=0 else 128-code
if __name__=='__main__':
 sys.exit(monitor(sys.argv[1:],os.environ.get('TASK17_FORENSIC_DIR',str(pathlib.Path(os.environ['RUNNER_TEMP'])/'task17-evidence'))))
