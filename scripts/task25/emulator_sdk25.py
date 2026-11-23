#!/usr/bin/env python3
"""Reviewed official stable SDK pin for disposable QA. No signing or app changes."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import urllib.request
import zipfile

from candidate25 import guard, GateError, SIGNING_KEYS, QA_WORKFLOW, write

VERSION = '37.3.10'
BUILD = '16970787'
URL = 'https://dl.google.com/android/repository/emulator-linux_x64-16970787.zip'
SIZE = 350068887
SHA1 = '5f7314368fc6c05c937f6991bb4106214dc389e7'
SHA256 = 'a4405349d8a9c52136ab7861e5331dc40e85574bd91cb8889a298a2ff4c52e26'


def qa_guard():
    root = guard()
    if os.environ.get('CANDIDATE25_WORKFLOW') != QA_WORKFLOW:
        raise GateError('QA_SDK_ONLY')
    if any(os.environ.get(k) for k in SIGNING_KEYS):
        raise GateError('SIGNING_BINDINGS_FORBIDDEN_IN_SDK_QA')
    return root


def members_checked(z):
    seen = set()
    infos = z.infolist()
    if len(infos) > 2000 or sum(i.file_size for i in infos) > 1500 * 1024**2:
        raise GateError('SDK_ARCHIVE_BOUNDS')
    for i in infos:
        p = PurePosixPath(i.filename)
        mode = i.external_attr >> 16
        if (not p.parts or p.parts[0] != 'emulator' or '..' in p.parts
                or p.is_absolute() or '\\' in i.filename or i.filename in seen
                or stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in (0, stat.S_IFDIR, stat.S_IFREG))):
            raise GateError('SDK_ARCHIVE_UNSAFE_MEMBER')
        seen.add(i.filename)
    if not {'emulator/emulator', 'emulator/source.properties'} <= seen:
        raise GateError('SDK_REQUIRED_FILES_MISSING')
    props = dict(line.split('=', 1) for line in z.read('emulator/source.properties').decode().splitlines() if '=' in line)
    if props.get('Pkg.Revision') != VERSION or props.get('Pkg.BuildId') != BUILD:
        raise GateError('SDK_PUBLISHER_VERSION_MISMATCH')
    return infos


def verify_archive(path):
    if path.is_symlink() or path.stat().st_size != SIZE:
        raise GateError('SDK_ARCHIVE_SIZE_OR_SYMLINK')
    for algorithm, expected in [('sha1', SHA1), ('sha256', SHA256)]:
        with path.open('rb') as f:
            if hashlib.file_digest(f, algorithm).hexdigest() != expected:
                raise GateError('SDK_ARCHIVE_PUBLISHER_HASH_MISMATCH')
    with zipfile.ZipFile(path) as z:
        members_checked(z)
        if z.testzip() is not None:
            raise GateError('SDK_ARCHIVE_CRC')


def install():
    root = qa_guard()
    if os.environ.get('TASK17_EMULATOR_PIN') != VERSION:
        raise GateError('SDK_WORKFLOW_PIN_MISMATCH')
    sdk = Path(os.environ['ANDROID_HOME'])
    target = sdk / 'emulator'
    if not sdk.is_absolute() or target.is_symlink() or not target.is_dir():
        raise GateError('EXISTING_DISPOSABLE_SDK_REQUIRED')
    archive = root / ('task25-sdk-' + BUILD + '.zip')
    if archive.exists():
        raise GateError('SDK_STAGE_ALREADY_EXISTS')
    total = 0
    with urllib.request.urlopen(URL, timeout=120) as response, archive.open('xb') as f:
        while chunk := response.read(1024**2):
            total += len(chunk)
            if total > SIZE:
                raise GateError('SDK_DOWNLOAD_SIZE_LIMIT')
            f.write(chunk)
    verify_archive(archive)  # No SDK mutation/execution before exact publisher pin.
    stage = root / 'task25-sdk-stage'
    backup = root / 'task25-previous-disposable-sdk'
    if stage.exists() or backup.exists():
        raise GateError('SDK_STAGE_NOT_FRESH')
    stage.mkdir()
    with zipfile.ZipFile(archive) as z:
        infos = members_checked(z)
        z.extractall(stage)
        for i in infos:
            if not i.is_dir():
                (stage / i.filename).chmod(stat.S_IMODE(i.external_attr >> 16) or 0o644)
    shutil.move(str(target), str(backup))
    try:
        shutil.move(str(stage / 'emulator'), str(target))
        result = subprocess.run([str(target / 'emulator'), '-no-window', '-version'],
                                capture_output=True, text=True, timeout=30)
        if result.returncode or not re.search(r'\bversion\s+37\.3\.10(?:\.0)?(?:\s|$)', result.stdout + result.stderr):
            raise GateError('SDK_ACTUAL_BINARY_VERSION_MISMATCH')
    except BaseException:
        if target.exists():
            shutil.rmtree(target)  # Only this newly installed disposable SDK.
        shutil.move(str(backup), str(target))
        raise
    receipt = {'status':'PASS_OFFICIAL_STABLE_EMULATOR_PIN', 'version':VERSION,
               'archiveSha256':SHA256, 'archiveSha1':SHA1, 'archiveBytes':SIZE,
               'validatedHeadlessVersion':True, 'publisherURL':URL,
               'newAppSigningKeyGenerated':False}
    write(root / 'task25-native-evidence/SDK_PIN_25.json', receipt)
    shutil.rmtree(backup)
    archive.unlink()
    return receipt


def record_ready(receipt):
    qa_guard()
    if not receipt_valid(receipt):
        raise GateError('SDK_READINESS_UNPROVEN')
    write(Path(os.environ['GITHUB_WORKSPACE']) / '.task17-sdk-ready.json', receipt)


def receipt_valid(value):
    return (isinstance(value, dict) and value.get('status') == 'PASS_OFFICIAL_STABLE_EMULATOR_PIN'
            and value.get('version') == VERSION and value.get('archiveSha256') == SHA256
            and value.get('archiveSha1') == SHA1 and value.get('archiveBytes') == SIZE
            and value.get('validatedHeadlessVersion') is True)


def ready_valid(path):
    try:
        return not path.is_symlink() and receipt_valid(json.loads(path.read_text()))
    except (OSError, ValueError):
        return False


def kernel_fault_records(text, pids):
    """Allowlisted module/relative IP only for this monitored QEMU; no raw logs."""
    records = []
    for line in text.splitlines():
        pid = re.search(r'\b(?:qemu-system[\w.-]*|emulator[\w.-]*)\[(\d+)\].*?segfault', line)
        if not pid or int(pid[1]) not in pids:
            continue
        module = re.search(r'\bin ([A-Za-z0-9_.+-]+)\[([0-9a-fA-F]+)\+([0-9a-fA-F]+)\]', line)
        row = {'pid':int(pid[1]), 'status':'MONITORED_HOST_SEGFAULT_MODULE_UNAVAILABLE'}
        if module and re.fullmatch(r'(?:lib[\w.+-]+\.so(?:\.[0-9]+)*|qemu-system-[\w-]+|ld-linux-[\w-]+\.so\.[0-9]+)', module[1]):
            row.update(status='MONITORED_HOST_SEGFAULT_CODE_MODULE', module=module[1])
            ip = re.search(r'\bip\s+([0-9a-fA-F]+)', line)
            if ip:
                relative = int(ip[1], 16) - int(module[2], 16)
                if 0 <= relative < int(module[3], 16):
                    row['instructionOffset'] = hex(relative)
        records.append(row)
        if len(records) >= 10:
            break
    return records


def collect_kernel():
    root = qa_guard()
    source = Path(os.environ['GITHUB_WORKSPACE']) / '.task17-forensics'
    pids = set()
    for p in source.glob('EMULATOR_FORENSIC_*.json'):
        value = json.loads(p.read_text())
        if value.get('avdLaunch') and value.get('signal') == 'SIGSEGV':
            pid = value.get('childPid')
            if isinstance(pid, int) and pid > 1:
                pids.add(pid)
    result = {'status':'NO_MONITORED_HOST_SIGSEGV', 'records':[],
              'rawKernelLogPublished':False, 'memoryOrStackPublished':False}
    if pids:
        try:
            run = subprocess.run(['sudo','-n','dmesg','--color=never','--time-format=raw'],
                                 capture_output=True, text=True, timeout=10)
            if run.returncode or len(run.stdout) > 4 * 1024**2:
                result['status'] = 'KERNEL_METADATA_UNAVAILABLE'
            else:
                result['records'] = kernel_fault_records(run.stdout, pids)
                result['status'] = 'SAFE_KERNEL_MODULE_METADATA' if result['records'] else 'NO_MATCHING_KERNEL_FAULT'
        except (OSError, subprocess.TimeoutExpired):
            result['status'] = 'KERNEL_METADATA_UNAVAILABLE'
    write(root / 'task25-native-evidence/forensics/KERNEL_MODULE_METADATA_25.json', result)
    print(json.dumps({'status':result['status'], 'records':len(result['records']), 'noRawKernelLog':True}))


if __name__ == '__main__':
    import sys
    if sys.argv[1:] != ['host-fault']:
        raise GateError('EXPLICIT_READ_ONLY_HOST_FAULT_MODE_REQUIRED')
    collect_kernel()
