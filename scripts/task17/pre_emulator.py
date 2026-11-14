"""Bounded resource hypothesis: smaller physical framebuffer, modern software GPU."""
import pathlib,shutil,os,subprocess
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
 original.write_text('#!/bin/sh\n# TASK17_MONITOR_WRAPPER\nexec /usr/bin/python3 '+shlex.quote(str(monitor))+' '+shlex.quote(str(real))+' "$@"\n')
 original.chmod(0o755)
 print('TASK17_CHILD_EXIT_MONITOR_INSTALLED; no renderer/app modification')
