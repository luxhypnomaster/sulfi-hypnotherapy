"""Actual signed26 app fault QA. Disposable emulator ONLY; no owner data.

Primary data is imported through UI. Only after that, deliberately arrange bad
input in THIS throwaway sandbox; compare bytes before/after failed bootstrap.
"""
import hashlib
import io
import json
import os
import pathlib
import struct
import subprocess
import tarfile
import time
import wave

import native_upgrade as ui


def relevant_files():
    raw = ui.adb('exec-out', 'run-as', ui.PKG, 'tar', '-cf', '-', 'files', binary=True)
    result = {}
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        for item in archive:
            if not item.isfile():
                continue
            if item.name.startswith(('files/library.sqlite', 'files/audio/',
                                     'files/diary_media/', 'files/history_media/')):
                result[item.name] = hashlib.sha256(archive.extractfile(item).read()).hexdigest()
    return result


def error_boot():
    ui.adb('shell', 'am', 'start', '-W', '-n', ui.PKG + '/ru.sulfi.sulfi_hypnotherapy.MainActivity')
    for _ in range(25):
        nodes = ui.tree()
        if any('Не удалось безопасно открыть локальные данные' in ui.label(n) for n in nodes):
            assert not any('НАЧАТЬ ТРАНСФОРМАЦИЮ' in ui.label(n) for n in nodes)
            return
        time.sleep(.5)
    raise AssertionError('NO_FAIL_CLOSED_ERROR_UI')


proof = {'kind': 'DISPOSABLE_EMULATOR_APP26_FAULT_ONLY', 'ownerData': 'NONE',
         'googleIdentities': 'NONE', 'primaryDatasetCreatedBy': 'ANDROID_UI', 'cases': []}
try:
    assert ui.adb('shell', 'getprop', 'ro.kernel.qemu').strip() == '1'
    assert 'Success' in ui.adb('install', str(pathlib.Path(os.environ['RUNNER_TEMP']) / 'task16v-ui-probe/probe.apk'))
    assert 'Success' in ui.adb('install', str(ui.APK / 'master26.apk'))
    assert ui.package_info()['versionCode'] == 26
    ui.adb('shell', 'wm', 'size', '720x1280')
    ui.adb('shell', 'wm', 'density', '280')
    ui.adb('shell', 'cmd', 'connectivity', 'airplane-mode', 'enable', check=False)
    ui.adb('shell', 'svc', 'wifi', 'disable', check=False)
    ui.adb('shell', 'svc', 'data', 'disable', check=False)
    fixture = ui.OUT / 'fault-fixture.wav'
    with wave.open(str(fixture), 'wb') as stream:
        stream.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
        stream.writeframes(struct.pack('<h', 1000) * 22050 * 12)
    ui.adb('push', str(fixture), '/sdcard/Download/task16g-fault.wav')
    ui.adb('shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
           '-d', 'file:///sdcard/Download/task16g-fault.wav', check=False)
    ui.launch()
    ui.import_audio('task16g-fault.wav', 'UI fault kept audio')
    healthy = ui.inventory('healthy26_fault_fixture')
    assert len(healthy['rows']['audio_assets']) == 1
    ui.adb('shell', 'am', 'force-stop', ui.PKG)
    payload = b'INVALID_SQLITE!!'
    assert len(payload) == 16
    damaged = subprocess.run(['adb', 'shell', '-T', 'run-as', ui.PKG, 'dd',
                              'of=files/library.sqlite', 'bs=16', 'count=1', 'conv=notrunc'],
                             input=payload, capture_output=True, timeout=55)
    assert damaged.returncode == 0, 'DISPOSABLE_FAULT_ARRANGEMENT_FAILED'
    corrupt = relevant_files()
    error_boot()
    after = relevant_files()
    assert after == corrupt, 'CORRUPT_BOOT_MUTATED_SOURCE_OR_MEDIA'
    proof['cases'].append({'case': 'actual_app_corrupt_boot', 'status': 'PASS',
                           'originalSourceAndMediaUnchanged': True,
                           'input': corrupt, 'after': after, 'errorUI': True})
    ui.adb('shell', 'am', 'force-stop', ui.PKG)
    ui.adb('shell', 'run-as', ui.PKG, 'mv', 'files/library.sqlite', 'files/library.sqlite.disposable-preserved')
    missing = relevant_files()
    assert 'files/library.sqlite' not in missing
    error_boot()
    assert relevant_files() == missing, 'MISSING_DB_RECREATED_OR_MEDIA_REMOVED'
    proof['cases'].append({'case': 'actual_app_missing_db_with_marker_and_media',
                           'status': 'PASS', 'sourceBackupAndMediaUnchanged': True,
                           'emptyLibraryNotCreated': True, 'errorUI': True})
    ui.adb('shell', 'am', 'force-stop', ui.PKG)
    ui.adb('shell', 'run-as', ui.PKG, 'mv', 'files/library.sqlite.storage-ready',
           'files/library.sqlite.marker-preserved')
    legacy_missing = relevant_files()
    error_boot()
    assert relevant_files() == legacy_missing, 'LEGACY_MEDIA_RESET_WITHOUT_MARKER'
    proof['cases'].append({'case': 'actual_app_missing_db_legacy_media_without_marker',
                           'status': 'PASS', 'sourceBackupAndMediaUnchanged': True,
                           'emptyLibraryNotCreated': True, 'errorUI': True})
except Exception as error:
    proof['cases'].append({'case': 'fault_driver', 'status': 'BLOCKED', 'reason': str(error)[:1800]})
finally:
    print('FAULT_APP_16G=' + json.dumps(proof), flush=True)
if any(case['status'] != 'PASS' for case in proof['cases']):
    raise SystemExit(2)
