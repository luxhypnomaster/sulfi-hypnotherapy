"""Inspect only minidump exception/module metadata. NEVER expose stack memory/env."""
import glob,json,os,pathlib,struct
reports=[]
for name in sorted(set(glob.glob('/tmp/android*',recursive=False))):
 root=pathlib.Path(name)
 if not root.is_dir():continue
 for p in root.rglob('*.dmp'):
  if len(reports)>=5:break
  if not p.is_file() or p.stat().st_size>64*1024*1024:continue
  size_total=p.stat().st_size
  def read_at(offset,length):
   assert 0<=offset and 0<=length<=8192 and offset+length<=size_total
   with p.open('rb') as source:source.seek(offset);return source.read(length)
  header=read_at(0,32)
  if header[:4]!=b'MDMP':continue
  count,directory=struct.unpack_from('<II',header,8);assert count<100 and directory+count*12<=size_total
  streams={}
  for i in range(count):
   kind,size,rva=struct.unpack('<III',read_at(directory+i*12,12))
   if rva+size<=size_total:streams[kind]=(rva,size)
  address=None;code=None;module=None
  if 6 in streams:
   x,size=streams[6]
   if size>=40:code=struct.unpack('<I',read_at(x+8,4))[0];address=struct.unpack('<Q',read_at(x+24,8))[0]
  if address is not None and 4 in streams:
   x,size=streams[4];n=struct.unpack('<I',read_at(x,4))[0];assert n<10000
   for i in range(n):
    a=x+4+i*108
    if a+108>x+size:break
    base,length=struct.unpack('<QI',read_at(a,12))
    if base<=address<base+length:
     rva=struct.unpack('<I',read_at(a+20,4))[0]
     if rva+4<=size_total:
      ln=struct.unpack('<I',read_at(rva,4))[0]
      if ln<=8192 and rva+4+ln<=size_total:
       raw=read_at(rva+4,ln).decode('utf-16-le',errors='replace').replace('\\','/').split('/')[-1]
       import re
       if re.fullmatch(r'(?:lib[A-Za-z0-9_.-]+\.so(?:\.\d+)*|qemu-system-x86_64|emulator(?:\.task17-real)?|ld-linux-x86-64\.so\.2)',raw):module={'basename':raw,'offsetHex':hex(address-base)}
     break
  reports.append({'bytes':size_total,'exceptionCode':code,'addressHex':hex(address) if address is not None else None,'faultModule':module,'rawMemoryExposed':False})
value={'classification':'HOST_EMULATOR_EXCEPTION_MODULE_METADATA_ONLY','reports':reports,'stackMemoryEnvironmentCredentials':'NOT_READ_OR_LOGGED','status':'METADATA_FOUND' if reports else 'NO_MINIDUMP_AVAILABLE_FAULT_FUNCTION_UNKNOWN'}
pathlib.Path(os.environ['RUNNER_TEMP'],'task18-evidence','EMULATOR_CRASH_METADATA_18.json').write_text(json.dumps(value,indent=2)+'\n')
print('EMULATOR_CRASH_METADATA_18='+json.dumps(value))
