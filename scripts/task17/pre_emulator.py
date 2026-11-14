"""Bounded resource hypothesis: smaller physical framebuffer, modern software GPU."""
import pathlib,shutil,os,subprocess
# Previous official patch release, selected only after observed QEMU SIGSEGV.
if os.environ.get('TASK17_EMULATOR_PIN')=='37.2.12':
 import urllib.request,hashlib,zipfile,stat
 archive=pathlib.Path(os.environ['RUNNER_TEMP'])/'emulator-16428233.zip'
 with urllib.request.urlopen('https://dl.google.com/android/repository/emulator-linux_x64-16428233.zip',timeout=120) as response,archive.open('wb') as output:
  shutil.copyfileobj(response,output,1024*1024)
 with archive.open('rb') as stream:assert hashlib.file_digest(stream,'sha256').hexdigest()=='b08fc43d8608d2955f607f1b287beb525041e730086bdca3af152accac3af9c1','OFFICIAL_ARCHIVE_SHA_MISMATCH_STOP'
 stage=pathlib.Path(os.environ['RUNNER_TEMP'])/'emulator-pinned-stage';stage.mkdir()
 with zipfile.ZipFile(archive) as z:
  for item in z.infolist():
   path=pathlib.PurePosixPath(item.filename)
   assert path.parts and path.parts[0]=='emulator' and '..' not in path.parts and not path.is_absolute(),'UNSAFE_SDK_ARCHIVE'
  z.extractall(stage)
  for item in z.infolist():
   if not item.is_dir():(stage/item.filename).chmod(stat.S_IMODE(item.external_attr>>16) or 0o644)
 target=pathlib.Path(os.environ['ANDROID_HOME'])/'emulator'
 shutil.rmtree(target);(stage/'emulator').rename(target)
 version=subprocess.check_output([str(target/'emulator'),'-version'],stderr=subprocess.STDOUT,text=True)
 assert '37.2.12' in version,'PINNED_VERSION_MISMATCH_STOP'
 print('TASK17_VERIFIED_OFFICIAL_EMULATOR=37.2.12; build16428233; archiveSHA256=b08fc43d8608d2955f607f1b287beb525041e730086bdca3af152accac3af9c1')
 archive.unlink()
folder=pathlib.Path.home()/'.android/avd/test.avd'
p=folder/'config.ini';config=dict(line.split('=',1) for line in p.read_text().splitlines() if '=' in line)
assert config.get('disk.dataPartition.size','').strip() in {'3G','3072M','3221225472'},'AVD_PARTITION_NOT_PINNED'
free=shutil.disk_usage(folder).free
assert free>=10*1024**3,'AVD_CAPACITY_BLOCKED_NO_BLIND_BOOT'
config.update({'hw.lcd.width':'720','hw.lcd.height':'1280','hw.lcd.density':'280'})
p.write_text('\n'.join(k+'='+v for k,v in config.items())+'\n')
print('TASK17_AVD_PHYSICAL=720x1280;GPU='+os.environ.get('TASK17_GLES_EXPERIMENT','swiftshader')+';FREE_BYTES='+str(free))

if os.environ.get('TASK17_GLES_EXPERIMENT') in {'swangle','lavapipe'}:
 tool=pathlib.Path(os.environ['ANDROID_HOME'])/'emulator/emulator'
 result=subprocess.run([str(tool),'-help-gpu'],capture_output=True,text=True,timeout=15)
 help_text=result.stdout+result.stderr
 assert os.environ['TASK17_GLES_EXPERIMENT'] in help_text.lower(),'RENDERER_NOT_ADVERTISED_STOP_NO_BLIND_BOOT'
 print('TASK17_EXPERIMENT_RENDERER='+os.environ['TASK17_GLES_EXPERIMENT']+'; no UI/data assertions removed')

if os.environ.get('TASK17_PROCESS_FORENSIC')=='true':
 import shlex
 original=pathlib.Path(os.environ['ANDROID_HOME'])/'emulator/emulator'
 real=original.with_name('emulator.task17-real')
 assert not real.exists(),'EMULATOR_ALREADY_WRAPPED_STOP'
 original.rename(real)
 monitor=pathlib.Path(__file__).with_name('monitor_emulator.py').resolve()
 original.write_text('#!/bin/sh\n# TASK17_MONITOR_WRAPPER\nexport TASK17_FORENSIC_DIR='+shlex.quote(str(pathlib.Path(os.environ['GITHUB_WORKSPACE'])/'.task17-forensics'))+'\nexec /usr/bin/python3 '+shlex.quote(str(monitor))+' '+shlex.quote(str(real))+' "$@"\n')
 original.chmod(0o755)
 print('TASK17_CHILD_EXIT_MONITOR_INSTALLED; no renderer/app modification')
