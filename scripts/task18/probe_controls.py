"""Actual notification/OS controls over synthetic native tasks; no Google/user data."""
import json,re,time,sqlite3,tarfile,subprocess,xml.etree.ElementTree as ET
from probe_snapshot import snapshot

class NativeControls:
 def __init__(self,adb,tree,click,launch,confirm,stats,out):
  self.adb,self.tree,self.click,self.launch,self.confirm,self.stats,self.out=adb,tree,click,launch,confirm,stats,out
 def save(self,name,value):
  (self.out/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n');return value
 def labels(self):return [(n.get('text') or n.get('content-desc') or '') for n in self.tree()]
 def receipt_generation(self,pkg):
  try:return json.loads(self.adb('shell','run-as',pkg,'cat','files/probe18-ui-destroy.json',check=False))['atMs']
  except (json.JSONDecodeError,KeyError):return 0
 def wait_state(self,pkg,phases,timeout=35):
  until=time.monotonic()+timeout;last=None
  while time.monotonic()<until:
   try:
    last=snapshot(pkg)
    q=[(k,v) for k,v in last['queues'].items() if v['work'].get('phase') in phases]
    if q:return last,q[0][0],q[0][1]
   except (RuntimeError,AssertionError,sqlite3.DatabaseError,tarfile.TarError):pass # active copying is not source corruption
   time.sleep(1)
  raise AssertionError('NO_OBSERVED_NATIVE_STATE:'+repr(phases)+':'+repr(last and {k:v['work'].get('phase') for k,v in last['queues'].items()}))
 def stable_counter(self,field):
  time.sleep(3);a=self.stats()[field];time.sleep(5);b=self.stats()[field]
  assert a==b,'BYTES_CONTINUED_AFTER_COOPERATIVE_STOP';return b
 def notification(self,label):
  self.adb('shell','input','keyevent','KEYCODE_WAKEUP');self.adb('shell','wm','dismiss-keyguard')
  self.adb('shell','cmd','statusbar','expand-notifications');time.sleep(1)
  try:
   # Shell command success did not prove an open shade on this OS image.
   for _ in range(3):
    ns=self.tree()
    if any(n.get('resource-id')=='com.android.systemui:id/notification_panel' for n in ns):break
    self.adb('shell','input','swipe','360','5','360','980','500');time.sleep(2)
   else:raise AssertionError('NATIVE_NOTIFICATION_SHADE_NOT_ACTUALLY_EXPOSED')
   for _ in range(6):
    nodes=self.tree()
    if not any(n.get('resource-id')=='com.android.systemui:id/notification_panel' for n in nodes):
     self.adb('shell','input','swipe','360','5','360','980','500');time.sleep(2);continue
    if any((n.get('text') or n.get('content-desc') or '').casefold()==label.casefold() for n in nodes):
     self.click(label);return
    titles=[n for n in nodes if 'CONTROLLED18' in ((n.get('text') or '')+' '+(n.get('content-desc') or ''))]
    if not titles:
     # A loading/grouped shade is not a reason to swipe up and close it.
     time.sleep(2);continue
    y=int(re.findall(r'\d+',titles[0].get('bounds',''))[1])
    expand=[n for n in nodes if 'expand' in n.get('resource-id','').lower() and n.get('enabled')!='false' and len(re.findall(r'\d+',n.get('bounds','')))>=4]
    expand.sort(key=lambda n:abs(int(re.findall(r'\d+',n.get('bounds',''))[1])-y))
    if not expand:break
    b=[int(v) for v in re.findall(r'\d+',expand[0]['bounds'] if isinstance(expand[0],dict) else expand[0].get('bounds',''))]
    self.adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));time.sleep(1)
   # Keep the actual missing-action window BEFORE finally collapses it.
   root=ET.Element('hierarchy')
   for node in nodes:ET.SubElement(root,'observed',dict(node.attrib))
   (self.out/'notification-action-missing.xml').write_bytes(ET.tostring(root))
   shot=subprocess.run(['adb','exec-out','screencap','-p'],capture_output=True,timeout=20)
   if shot.returncode==0:(self.out/'notification-action-missing.png').write_bytes(shot.stdout)
   (self.out/'notification-native-readback.txt').write_text(self.adb('shell','dumpsys','notification','--noredact',check=False)[:120000])
   raise AssertionError('NATIVE_NOTIFICATION_ACTION_NOT_EXPOSED:'+label)
  finally:self.adb('shell','cmd','statusbar','collapse')
 def master_pause_resume(self,pkg):
  self.notification('Пауза');before,name,row=self.wait_state(pkg,['paused'])
  assert row['work']['pauseReason']=='USER_PAUSED' and row['work']['state']=='PAUSED_BY_USER','HOME_IS_NOT_USER_PAUSE'
  stable=self.stable_counter('uploaded');self.save('master-notification-user-paused',before)
  original_uploads=before['uploads'];generation=self.receipt_generation(pkg)
  # Explicit stopped-package boundary is NOT claimed to auto-resume.
  self.adb('shell','am','force-stop',pkg);self.launch(pkg);self.click('READ INVENTORY');time.sleep(1)
  paused=snapshot(pkg);assert paused['queues'][name]['work']['phase']=='paused'
  assert paused['queues'][name]['work']['taskId']==row['work']['taskId']
  assert self.stats()['uploaded']==stable,'MANUAL_PAUSE_RESUMED_WITHOUT_USER'
  self.save('master-user-paused-cold-restart',paused)
  pid=self.adb('shell','pidof',pkg).strip();self.click('UPLOAD AND DESTROY UI');self.confirm(pkg,pid,generation)
  until=time.monotonic()+50
  while time.monotonic()<until:
   after=snapshot(pkg)
   if after['queues'][name]['work']['phase']=='running' and self.stats()['uploaded']>stable:break
   time.sleep(1)
  else:raise AssertionError('EXPLICIT_SAME_OWNER_RESUME_DID_NOT_PROGRESS')
  assert after['queues'][name]['work']['taskId']==row['work']['taskId'],'RESUME_REPLACED_TASK_ID'
  assert after['sourceFiles']==before['sourceFiles'],'PERSONAL_SOURCE_BYTES_CHANGED'
  for key,old in original_uploads.items():
   new=after['uploads'][key]
   assert new['sessionId']==old['sessionId'] and new['requestId']==old['requestId'] and new['offset']>=old['offset'],'UPLOAD_CHECKPOINT_REPLACED'
  self.adb('shell','input','keyevent','KEYCODE_SLEEP');self.save('master-explicit-resume',after)
  return {'taskIdPreserved':True,'sourceHashesPreserved':True,'requestAndSessionPreserved':True,'forceStop':'NO_AUTO_RESUME_CLAIM_EXPLICIT_USER_START_ONLY'}
 def master_process_loss(self,pkg):
  assert self.adb('shell','getprop','ro.kernel.qemu').strip()=='1','EMULATOR_ONLY_PROCESS_LOSS'
  before,name,row=self.wait_state(pkg,['running'])
  assert 'stopped=false' in self.adb('shell','dumpsys','package',pkg),'NO_STOPPED_PACKAGE_BYPASS'
  pid=self.adb('shell','pidof',pkg).strip();assert pid.isdigit()
  count=self.stats()['uploaded'];started=time.monotonic()
  self.save('master-before-process-loss',before)
  self.adb('shell','run-as',pkg,'kill','-9',pid) # SIGKILL is NOT Android Force Stop
  until=time.monotonic()+660;newpid='';after=None
  while time.monotonic()<until:
   newpid=self.adb('shell','pidof',pkg,check=False).strip()
   # At most one prior request was in flight. Two further unique chunks plus
   # a different actual PID proves a new OS-started worker, not its old reply.
   if newpid and newpid!=pid and self.stats()['uploaded']>=count+524288:
    after=snapshot(pkg);break
   time.sleep(3)
  if after is None:
   self.save('master-process-loss-blocked',{'oldPid':pid,'newPid':newpid,'jobs':self.adb('shell','dumpsys','jobscheduler',pkg),'stats':self.stats()})
   raise AssertionError('NO_OBSERVED_OS_COLD_PROCESS_RECOVERY_WITHIN_WATCHDOG_BUDGET')
  assert after['queues'][name]['work']['taskId']==row['work']['taskId'],'PROCESS_LOSS_REPLACED_TASK_ID'
  assert after['sourceFiles']==before['sourceFiles'],'PROCESS_LOSS_CHANGED_PERSONAL_SOURCE_BYTES'
  for key,old in before['uploads'].items():
   fresh=after['uploads'][key]
   assert fresh['requestId']==old['requestId'] and fresh['sessionId']==old['sessionId'] and fresh['offset']>=old['offset'],'PROCESS_LOSS_REPLACED_UPLOAD_CHECKPOINT'
  assert 'stopped=false' in self.adb('shell','dumpsys','package',pkg),'UNEXPECTED_STOPPED_FLAG'
  proof={'oldPid':pid,'newPid':newpid,'elapsedSeconds':round(time.monotonic()-started,2),'taskIdAndSourceHashesPreserved':True,'requestSessionOffsetsPreserved':True,'recovery':'ACTUAL_OS_NO_UI_NO_FORCE_RUN_NO_FORCE_STOP_BYPASS','Google':'NOT_RUN'}
  self.save('master-actual-process-loss-recovered',{'proof':proof,'after':after});return proof
 def client_network_cancel_resume(self,pkg):
  self.adb('shell','cmd','connectivity','airplane-mode','enable',check=False);self.adb('shell','svc','wifi','disable');self.adb('shell','svc','data','disable')
  try:
   before,name,row=self.wait_state(pkg,['paused','waiting_network','waiting_policy','retry_scheduled'],timeout=45)
   assert row['work'].get('pauseReason')!='USER_PAUSED' and row['work'].get('code')!='USER_PAUSED','NETWORK_LOSS_BECAME_USER_PAUSE'
   stable=self.stable_counter('downloaded');self.save('client-network-wait',before)
  finally:
   self.adb('shell','cmd','connectivity','airplane-mode','disable',check=False);self.adb('shell','svc','wifi','enable');self.adb('shell','svc','data','enable')
  until=time.monotonic()+120
  while time.monotonic()<until:
   if self.stats()['downloaded']>stable:break
   time.sleep(2)
  else:
   # Diagnose the actual FGS/JobScheduler/network boundary before another run.
   # Read-only on the disposable probe: no force-run, UI start, or user Resume.
   self.save('client-network-recovery-blocked',{'snapshot':snapshot(pkg),'stats':self.stats(),
    'jobs':self.adb('shell','dumpsys','jobscheduler',pkg,check=False),
    'services':self.adb('shell','dumpsys','activity','services',pkg,check=False),
    'network':self.adb('shell','dumpsys','connectivity',check=False)[-40000:]})
   raise AssertionError('NO_OS_NETWORK_RECOVERY_WITHOUT_UI_OR_RESUME')
  resumed=snapshot(pkg);assert resumed['queues'][name]['work']['taskId']==row['work']['taskId']
  self.save('client-network-automatic-recovery',resumed)
  self.notification('Отменить');cancelled,_,cancelrow=self.wait_state(pkg,['cancelled'])
  self.stable_counter('downloaded')
  # Cancel marks intent immediately; the one in-flight request may still flush.
  # Observe the durable boundary after quiescence, not an earlier transient copy.
  cancelled=snapshot(pkg);assert cancelled['queues'][name]['work']['phase']=='cancelled'
  self.save('client-notification-cancelled',cancelled)
  assert self.stats()['publishedPrograms']==1,'CANCEL_UNPUBLISHED_SERVER_CONTENT'
  generation=self.receipt_generation(pkg);ranges=len(self.stats().get('downloadRanges',[]))
  self.launch(pkg);self.click('READ INVENTORY');time.sleep(1)
  observed=snapshot(pkg);assert observed['queues'][name]['work']['phase']=='cancelled'
  pid=self.adb('shell','pidof',pkg).strip();self.click('DOWNLOAD AND DESTROY UI');self.confirm(pkg,pid,generation)
  until=time.monotonic()+50
  while time.monotonic()<until:
   rs=self.stats().get('downloadRanges',[])
   if len(rs)>ranges:break
   time.sleep(1)
  else:raise AssertionError('NO_RESUME_RANGE_AFTER_EXPLICIT_RETRY')
  first=rs[ranges];checkpoints={r['assetRevisionId']:r for r in cancelled['downloadCheckpoints'].values()}
  expected=checkpoints.get(first['assetRevisionId'],{}).get('offset',0)
  assert first['offset']==expected,'NATIVE_DOWNLOAD_DID_NOT_RESUME_EXACT_RECORDED_BOUNDARY'
  after=snapshot(pkg);assert after['queues'][name]['work']['taskId']==cancelrow['work']['taskId']
  assert after['sourceFiles']==cancelled['sourceFiles'],'CANCEL_OR_RESUME_REMOVED_EXISTING_LOCAL_SOURCE'
  self.adb('shell','input','keyevent','KEYCODE_SLEEP');self.save('client-cancel-explicit-range-resume',{'snapshot':after,'firstRange':first,'expectedOffset':expected})
  return {'networkAutomaticNoUI':True,'cancelReceiptPreserved':True,'sameTaskId':True,'exactRangeResume':True,'unpublish':'NOT_PERFORMED'}
