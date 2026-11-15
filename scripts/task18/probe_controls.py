"""Actual notification/OS controls over synthetic native tasks; no Google/user data."""
import json,re,time,sqlite3,tarfile
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
   for _ in range(4):
    nodes=self.tree()
    if any((n.get('text') or n.get('content-desc') or '').casefold()==label.casefold() for n in nodes):
     self.click(label);return
    titles=[n for n in nodes if 'CONTROLLED18' in ((n.get('text') or '')+' '+(n.get('content-desc') or ''))]
    if not titles:
     self.adb('shell','input','swipe','360','1050','360','400','400');time.sleep(1);continue
    y=int(re.findall(r'\d+',titles[0].get('bounds',''))[1])
    expand=[n for n in nodes if 'expand' in n.get('resource-id','').lower() and n.get('enabled')!='false' and len(re.findall(r'\d+',n.get('bounds','')))>=4]
    expand.sort(key=lambda n:abs(int(re.findall(r'\d+',n.get('bounds',''))[1])-y))
    if not expand:break
    b=[int(v) for v in re.findall(r'\d+',expand[0]['bounds'] if isinstance(expand[0],dict) else expand[0].get('bounds',''))]
    self.adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));time.sleep(1)
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
  else:raise AssertionError('NO_OS_NETWORK_RECOVERY_WITHOUT_UI_OR_RESUME')
  resumed=snapshot(pkg);assert resumed['queues'][name]['work']['taskId']==row['work']['taskId']
  self.save('client-network-automatic-recovery',resumed)
  self.notification('Отменить');cancelled,_,cancelrow=self.wait_state(pkg,['cancelled'])
  self.stable_counter('downloaded');self.save('client-notification-cancelled',cancelled)
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
