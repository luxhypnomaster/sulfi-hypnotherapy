#!/usr/bin/env python3
"""Opt-in disposable-host PC diagnosis. Never a delivery or preservation PASS.

The debugger reads registers and executable mappings only. No guest memory,
stack unwinding, environment, raw debugger transcript or core is published.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

from candidate25 import GateError, write
from emulator_sdk25 import qa_guard
import android_graphics25 as graphics25

CONTROL_SCRIPT = '''import os, signal, resource
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
signal.signal(signal.SIGUSR1, signal.SIG_IGN)
signal.signal(signal.SIGUSR2, signal.SIG_IGN)
os.kill(os.getpid(), signal.SIGUSR1)
os.kill(os.getpid(), signal.SIGUSR2)
os.kill(os.getpid(), signal.SIGSEGV)
'''


def instruction_module(maps, pc):
    """Allowlisted public code filename and file offset; omit ASLR addresses."""
    for line in maps.splitlines():
        parts = line.split(None, 5)
        if len(parts) != 6 or 'x' not in parts[1]:
            continue
        bounds = parts[0].split('-')
        if len(bounds) != 2:
            continue
        try:
            start, end = (int(x, 16) for x in bounds)
            offset = int(parts[2], 16)
        except ValueError:
            continue
        if not start <= pc < end:
            continue
        name = Path(parts[5]).name
        if not re.fullmatch(r'(?:lib[\w.+-]+\.so(?:\.[0-9]+)*|qemu-system-[\w-]+|ld-linux-[\w-]+\.so\.[0-9]+|dash|bash)', name):
            return {'status': 'EXECUTABLE_MODULE_NOT_ALLOWLISTED'}
        return {'status': 'EXECUTABLE_INSTRUCTION_MODULE', 'module': name,
                'instructionFileOffset': hex(pc - start + offset)}
    return {'status': 'NO_EXECUTABLE_MAPPING_FOR_PC'}


# GDB captures its own transcript in memory; it is deliberately never printed.
# A stop can be handled by the SDK: only final terminatedWithSIGSEGV confirms a
# fatal signal. Original signals are passed, not suppressed or recovered.
GDB_SCRIPT = r'''
set pagination off
set confirm off
set logging file /dev/null
set logging redirect on
set logging enabled on
set print thread-events off
set disable-randomization off
set follow-fork-mode parent
set follow-exec-mode same
set detach-on-fork on
handle SIGPIPE nostop noprint pass
handle SIGUSR1 nostop noprint pass
handle SIGUSR2 nostop noprint pass
handle SIGALRM nostop noprint pass
handle SIGSEGV stop print pass
python
import gdb, json, os, sys
from pathlib import Path
sys.path.insert(0, os.environ['TASK25_PC_HELPER_DIRECTORY'])
from emulator_pc25 import instruction_module
out = Path(os.environ['TASK25_PC_RESULT'])
report = {'schema':1, 'status':'DEBUGGER_STARTED', 'signals':[],
          'avdLaunch':os.environ.get('TASK25_PC_AVD_LAUNCH') == 'true',
          'terminatedWithSIGSEGV':False, 'exitCode':None,
          'guestMemoryRead':False, 'stackUnwound':False,
          'rawDebuggerTranscriptPublished':False, 'corePublished':False}
stopped = {'signal':None}
def on_stop(event):
    stopped['signal'] = event.stop_signal if isinstance(event, gdb.SignalEvent) else None
def on_exit(event):
    report['exitCode'] = getattr(event, 'exit_code', None)
gdb.events.stop.connect(on_stop)
gdb.events.exited.connect(on_exit)
def save():
    out.write_text(json.dumps(report,indent=2)+'\n')
save()
try:
    command = 'run'
    for turn in range(9):
        stopped['signal'] = None
        transcript = gdb.execute(command, to_string=True)
        command = 'continue'
        if gdb.selected_inferior().pid == 0:
            try:
                exit_signal = int(gdb.parse_and_eval('$_exitsignal'))
            except (gdb.error, TypeError, ValueError):
                exit_signal = None
            report['terminationSignal'] = exit_signal
            report['terminatedWithSIGSEGV'] = exit_signal == 11
            report['status'] = 'FATAL_SIGSEGV_PC_CAPTURED' if report['terminatedWithSIGSEGV'] else 'INFERIOR_EXITED'
            save()
            break
        if stopped['signal'] != 'SIGSEGV':
            report['status'] = 'UNEXPECTED_DEBUGGER_STOP_NO_PASS'
            report['unexpectedSignal'] = stopped['signal']
            save()
            break
        pc = int(gdb.parse_and_eval('$pc'))
        pid = gdb.selected_inferior().pid
        row = instruction_module(Path('/proc/%d/maps' % pid).read_text(), pc)
        row['signal'] = 'SIGSEGV'
        report['signals'].append(row)
        report['status'] = 'SIGNAL_PC_CAPTURED_NOT_YET_FATAL'
        save()
        if turn == 7:
            gdb.execute('handle SIGSEGV nostop noprint pass', to_string=True)
    else:
        report['status'] = 'DEBUGGER_SIGNAL_BOUND_REACHED_NO_PASS'
        save()
except Exception as error:
    report['status'] = 'DEBUGGER_DIAGNOSTIC_ERROR_NO_PASS'
    report['errorType'] = type(error).__name__
    save()
end
'''


def gdb_path():
    gdb = shutil.which('gdb')
    if gdb != '/usr/bin/gdb':
        raise GateError('HOST_GDB_UNAVAILABLE_STOP_BEFORE_EMULATOR_ACTION')
    return gdb


def fingerprint(gdb):
    with open(gdb, 'rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def control_valid(value, gdb):
    return (value.get('status') == 'PASS_REAL_PC_HOST_CONTROL'
            and value.get('gdbSHA256') == fingerprint(gdb)
            and value.get('scriptSHA256') == hashlib.sha256(GDB_SCRIPT.encode()).hexdigest())


def host_preflight():
    root = qa_guard()
    if os.environ.get('TASK25_PC_DIAGNOSTIC') != 'true':
        raise GateError('EXPLICIT_PC_DIAGNOSTIC_REQUIRED')
    gdb = gdb_path()
    out = root / 'task25-native-evidence/forensics'
    out.mkdir(parents=True, exist_ok=True)
    script = root / 'task25-pc.gdb'
    script.write_text(GDB_SCRIPT)
    control_script = root / 'task25-pc-control.py'
    control_script.write_text(CONTROL_SCRIPT)
    env = dict(os.environ, TASK25_PC_HELPER_DIRECTORY=str(Path(__file__).resolve().parent),
               TASK25_PC_AVD_LAUNCH='false',
               TASK25_PC_RESULT=str(out / 'PC_SELFTEST_25.json'))
    run = subprocess.run([gdb, '--batch', '--nx', '--return-child-result',
                          '-iex', 'set auto-load off', '-iex', 'set startup-with-shell off',
                          '--command', str(script), '--args', '/usr/bin/python3', str(control_script)],
                         env=env, capture_output=True, timeout=30)
    result = json.loads((out / 'PC_SELFTEST_25.json').read_text())
    if not (result.get('terminatedWithSIGSEGV') is True and result.get('signals')
            and result['signals'][0].get('status') == 'EXECUTABLE_INSTRUCTION_MODULE'):
        raise GateError('GDB_PC_CONTROL_FAILED_NO_ANDROID_RUN')
    control = {'status':'PASS_REAL_PC_HOST_CONTROL', 'selftestExit':run.returncode,
               'gdbSHA256':fingerprint(gdb),
               'scriptSHA256':hashlib.sha256(GDB_SCRIPT.encode()).hexdigest()}
    write(root / 'task25-pc-host-ready.json', control)
    write(out / 'PC_HOST_CONTROL_25.json', control)
    print('PASS_REAL_HOST_PC_CONTROL_BEFORE_ANY_EMULATOR_ACTION')


def prepare():
    root = qa_guard()
    enabled = os.environ.get('TASK25_PC_DIAGNOSTIC', 'false')
    if enabled == 'false':
        return
    if enabled != 'true':
        raise GateError('EXPLICIT_PC_DIAGNOSTIC_REQUIRED')
    gdb = gdb_path()
    ready = root / 'task25-pc-host-ready.json'
    if not ready.is_file() or ready.is_symlink():
        raise GateError('REAL_HOST_PC_CONTROL_RECEIPT_REQUIRED')
    control = json.loads(ready.read_text())
    if not control_valid(control, gdb):
        raise GateError('REAL_HOST_PC_CONTROL_RECEIPT_DRIFT')
    out = root / 'task25-native-evidence/forensics'
    script = root / 'task25-pc.gdb'
    if script.is_symlink() or script.read_text() != GDB_SCRIPT:
        raise GateError('REVIEWED_GDB_SCRIPT_DRIFT')
    env = dict(os.environ, TASK25_PC_HELPER_DIRECTORY=str(Path(__file__).resolve().parent))
    target = Path(os.environ['ANDROID_HOME']) / 'emulator/emulator.task17-real'
    saved = target.with_name('emulator.task25-pc-target')
    if target.is_symlink() or not target.is_file() or saved.exists():
        raise GateError('EXACT_MONITORED_DISPOSABLE_EMULATOR_REQUIRED')
    target.rename(saved)
    env['TASK25_PC_RESULT'] = str(out / 'PC_FAULT_MODULE_25.json')
    wrapper = ('#!/usr/bin/python3\nimport os,sys\n'
               + "avd = '-avd' in sys.argv[1:]\n"
               + "os.environ['TASK25_PC_AVD_LAUNCH']='true' if avd else 'false'\n"
               + 'if avd:\n    with open(%r,"x") as marker: marker.write("1")\n' % str(root / 'task25-observed-avd-launch.marker')
               + ''.join('os.environ[%r]=%r\n' % (k, env[k]) for k in
                         ['TASK25_PC_HELPER_DIRECTORY', 'TASK25_PC_RESULT'])
               + 'if not avd: os.environ["TASK25_PC_RESULT"]=%r\n' % str(out / 'PC_UTILITY_25.json')
               + 'os.execv(%r,%r+sys.argv[1:])\n' %
               (gdb, [gdb, '--batch', '--nx', '--return-child-result',
                      '-iex', 'set auto-load off', '-iex', 'set startup-with-shell off',
                      '--command', str(script), '--args', str(saved)]))
    target.write_text(wrapper)
    target.chmod(0o755)
    write(out / 'PC_DIAGNOSTIC_SETUP_25.json', {
        'status':'CONTROLLED_GDB_PC_SELFTEST_PASS_DIAGNOSTIC_ONLY',
        'debugger':'/usr/bin/gdb', 'normalSignalsPassed':True,
        'selftestExit':control['selftestExit'], 'applicationOrDataModified':False,
        'signingOrDeliveryEnabled':False})
    print('HOST_PC_DIAGNOSTIC_READY_SELFTEST_PASS_NO_RAW_DEBUGGER_OUTPUT')


def read_finished_pc(path):
    """Bounded read-only completion wait, never retry a native action."""
    value = {}
    for attempt in range(40):
        try:
            value = json.loads(path.read_text())
        except (OSError, ValueError):
            value = {}
        if value.get('signals') or value.get('status') not in {None, 'DEBUGGER_STARTED', 'SIGNAL_PC_CAPTURED_NOT_YET_FATAL'}:
            return value
        if attempt < 39:
            time.sleep(0.25)
    return value


def verify_terminal():
    """Extra full-QA gate. A debugger can never recover a failed native test."""
    root = qa_guard()
    out = root / 'task25-native-evidence'
    marker = root / 'task25-observed-avd-launch.marker'
    pc_path = out / 'forensics/PC_FAULT_MODULE_25.json'
    report_path = out / 'NATIVE_UPGRADE_25.json'
    ready = root / 'task25-pc-host-ready.json'
    for path in [marker, pc_path, report_path, ready]:
        if path.is_symlink() or not path.is_file():
            raise GateError('OBSERVED_NATIVE_TERMINAL_EVIDENCE_MISSING')
    pc = read_finished_pc(pc_path)
    control = json.loads(ready.read_text())
    if not (marker.read_text() == '1' and control_valid(control, gdb_path())
            and pc.get('status') == 'INFERIOR_EXITED' and pc.get('avdLaunch') is True
            and type(pc.get('exitCode')) is int and pc['exitCode'] == 0 and pc.get('terminationSignal') is None
            and pc.get('terminatedWithSIGSEGV') is False and pc.get('signals') == []
            and all(pc.get(k) is False for k in ['guestMemoryRead','stackUnwound',
                                                'rawDebuggerTranscriptPublished','corePublished'])):
        raise GateError('HOST_TERMINAL_NOT_CLEAN_NO_NATIVE_DELIVERY')
    report = json.loads(report_path.read_text())
    if not report.get('cases') or not all(c.get('status') == 'PASS' for c in report['cases']):
        raise GateError('ORIGINAL_NATIVE_CASES_NOT_ALL_PASS')
    graphics = graphics25.request_proof(root, graphics25.IDS[report['edition']])
    proof = {'status':'PASS_CLEAN_OBSERVED_QEMU_EXIT','avdLaunchCount':1,
             'hostExitCode':0,'hostSIGSEGVCount':0,'signalPolicy':'PASS_ORIGINAL_SIGNALS',
             'restarts':0,'selftest':'PASS_REAL_PC_HOST_CONTROL',
             'observerScriptSHA256':control['scriptSHA256'],
             'gdbSHA256':control['gdbSHA256'],
             'scope':'HOST_OBSERVED_CONTROLLED_ANDROID_NOT_PHYSICAL'}
    report['hostObserver'] = proof  # Only add proof; never change cases/data inventories.
    report['graphicsRequest'] = graphics
    write(report_path, report)
    write(out / 'forensics/PC_CLEAN_EXIT_GATE_25.json', proof)
    print('PASS_CLEAN_OBSERVED_QEMU_EXIT_ORIGINAL_NATIVE_CASES_UNCHANGED')


if __name__ == '__main__':
    import sys
    if sys.argv[1:] == ['--host-preflight']:
        host_preflight()
    elif sys.argv[1:] == ['--verify-terminal']:
        verify_terminal()
    else:
        raise GateError('EXPLICIT_HOST_OPERATION_REQUIRED')
