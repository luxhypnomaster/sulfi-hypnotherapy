"""Fail before boot if the actual disposable AVD layout cannot fit."""
import pathlib
import shutil

folder = pathlib.Path.home() / '.android/avd/test.avd'
config = dict(line.split('=', 1) for line in (folder / 'config.ini').read_text().splitlines()
              if '=' in line)
size = config.get('disk.dataPartition.size', '').strip()
assert size in {'3G', '3072M', '3221225472'}, 'AVD_PARTITION_NOT_PINNED:' + size
free = shutil.disk_usage(folder).free
print('AVD16G_PARTITION=' + size + ';FREE_BYTES=' + str(free))
assert free >= 4 * 1024**3, 'AVD_CAPACITY_GATE_BLOCKED; no blind boot wait'
