"""Bounded resource hypothesis: smaller physical framebuffer, modern software GPU."""
import pathlib,shutil
folder=pathlib.Path.home()/'.android/avd/test.avd'
p=folder/'config.ini';config=dict(line.split('=',1) for line in p.read_text().splitlines() if '=' in line)
assert config.get('disk.dataPartition.size','').strip() in {'3G','3072M','3221225472'},'AVD_PARTITION_NOT_PINNED'
free=shutil.disk_usage(folder).free
assert free>=10*1024**3,'AVD_CAPACITY_BLOCKED_NO_BLIND_BOOT'
config.update({'hw.lcd.width':'720','hw.lcd.height':'1280','hw.lcd.density':'280'})
p.write_text('\n'.join(k+'='+v for k,v in config.items())+'\n')
print('TASK17_AVD_PHYSICAL=720x1280;GPU=swiftshader;FREE_BYTES='+str(free))
