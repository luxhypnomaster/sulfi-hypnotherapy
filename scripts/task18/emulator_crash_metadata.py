"""Inspect only minidump exception/module metadata. NEVER expose stack memory/env."""
import glob,json,os,pathlib,struct
reports=[]
for name in sorted(set(glob.glob('/tmp/android*',recursive=False))):
 root=pathlib.Path(name)
 if not root.is_dir():continue
 for p in root.rglob('*.dmp'):
  if len(reports)>=5:break
  if not p.is_file() or p.stat().st_size>64*1024*1024:continue
  b=p.read_bytes()
  if b[:4]!=b'MDMP':continue
  count,directory=struct.unpack_from('<II',b,8);assert count<100 and directory+count*12<=len(b)
  streams={}
  for i in range(count):
   kind,size,rva=struct.unpack_from('<III',b,directory+i*12)
   if rva+size<=len(b):streams[kind]=(rva,size)
  address=None;code=None;module=None
  if 6 in streams:
   x,size=streams[6]
   if size>=40:code=struct.unpack_from('<I',b,x+8)[0];address=struct.unpack_from('<Q',b,x+24)[0]
  if address is not None and 4 in streams:
   x,size=streams[4];n=struct.unpack_from('<I',b,x)[0];assert n<10000
   for i in range(n):
    a=x+4+i*108
    if a+108>x+size:break
    base,length=struct.unpack_from('<QI',b,a)
    if base<=address<base+length:
     rva=struct.unpack_from('<I',b,a+20)[0]
     if rva+4<=len(b):
      ln=struct.unpack_from('<I',b,rva)[0]
      if ln<=8192 and rva+4+ln<=len(b):
       raw=b[rva+4:rva+4+ln].decode('utf-16-le',errors='replace').replace('\\','/').split('/')[-1]
       import re
       if re.fullmatch(r'[A-Za-z0-9_.-]{1,150}',raw):module={'basename':raw,'offsetHex':hex(address-base)}
     break
  reports.append({'bytes':len(b),'exceptionCode':code,'addressHex':hex(address) if address is not None else None,'faultModule':module,'rawMemoryExposed':False})
value={'classification':'HOST_EMULATOR_EXCEPTION_MODULE_METADATA_ONLY','reports':reports,'stackMemoryEnvironmentCredentials':'NOT_READ_OR_LOGGED','status':'METADATA_FOUND' if reports else 'NO_MINIDUMP_AVAILABLE_FAULT_FUNCTION_UNKNOWN'}
pathlib.Path(os.environ['RUNNER_TEMP'],'task18-evidence','EMULATOR_CRASH_METADATA_18.json').write_text(json.dumps(value,indent=2)+'\n')
print('EMULATOR_CRASH_METADATA_18='+json.dumps(value))
