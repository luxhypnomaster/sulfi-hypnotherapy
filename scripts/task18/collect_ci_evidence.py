"""Read CI logs only; accept bounded synthetic evidence after SHA and size checks."""
import argparse,base64,hashlib,json,pathlib,re,zipfile
p=argparse.ArgumentParser();p.add_argument('logs');p.add_argument('output');args=p.parse_args()
out=pathlib.Path(args.output);out.mkdir(parents=True,exist_ok=True)
receipts=[]
with zipfile.ZipFile(args.logs) as z:
 for job in z.namelist():
  if '/' in job or not job.endswith('.txt'):continue # root logs only, not duplicated steps
  scope='probe' if re.search(r'\d+_probe18\.txt$',job) else 'master' if 'native18 (master,' in job else 'client' if 'native18 (client,' in job else None
  if scope is None:continue
  metadata={};chunks={};totals={}
  for raw in z.read(job).decode(errors='replace').splitlines():
   if re.search(r'TASK18_FILE_META=\{"',raw):
    v=json.loads(raw.split('TASK18_FILE_META=',1)[1]);metadata[v['file']]=v
   m=re.search(r'TASK18_FILE_CHUNK=([^:]+):(\d+):([A-Za-z0-9+/=]+)$',raw)
   if m:
    name,index,data=m.groups();key=(name,int(index));value=base64.b64decode(data,validate=True)
    if key in chunks:assert chunks[key]==value,'CONFLICTING_DUPLICATE_CHUNK'
    chunks[key]=value
   m=re.search(r'NATIVE18_DIGEST=([^:]+):([a-f0-9]{64})$',raw)
   if m:metadata[m[1]]={'file':m[1],'sha256':m[2]}
   m=re.search(r'NATIVE18_CHUNK=([^:]+):(\d+):(\d+):([A-Za-z0-9+/=]+)$',raw)
   if m:
    name,index,total,data=m.groups();key=(name,int(index));totals[name]=int(total)
    # Upgrade codec splits one continuous base64 string, so decode after join.
    if key in chunks:assert chunks[key]==data,'CONFLICTING_DUPLICATE_CHUNK'
    chunks[key]=data
  for name,v in metadata.items():
   assert re.fullmatch(r'[A-Za-z0-9_.-]{1,150}',name),'UNSAFE_EVIDENCE_NAME'
   indexes=sorted(i for (n,i) in chunks if n==name)
   assert (indexes or v.get('bytes')==0) and indexes==list(range(len(indexes))),'MISSING_CHUNK:'+name
   if name in totals:
    assert len(indexes)==totals[name],'INCOMPLETE_EVIDENCE:'+name
    data=base64.b64decode(''.join(chunks[name,i] for i in indexes),validate=True)
   else:data=b''.join(chunks[name,i] for i in indexes)
   assert len(data)<=8*1024*1024,'EVIDENCE_TOO_LARGE'
   assert hashlib.sha256(data).hexdigest()==v['sha256'],'SHA_MISMATCH:'+name
   assert v.get('bytes',len(data))==len(data),'SIZE_MISMATCH:'+name
   target=out/scope/name;target.parent.mkdir(exist_ok=True);target.write_bytes(data)
   receipts.append({'job':job,'path':str(target.relative_to(out)),'bytes':len(data),'sha256':v['sha256']})
assert receipts,'NO_VERIFIABLE_NATIVE_EVIDENCE'
(out/'READBACK.json').write_text(json.dumps(receipts,indent=2)+'\n');print(json.dumps({'files':len(receipts),'status':'SHA_SIZE_VERIFIED','scope':'SYNTHETIC_CI_NATIVE_ONLY'}))
