#!/usr/bin/env python3
"""Official Flutter emulator-only launch flags; no APK/data/UI substitution.

Records acknowledged launch requests, NOT an invented runtime backend readback.
The pinned Flutter CLI/embedding supports these extras; physical GPU remains QA.
"""
import json
import os
from pathlib import Path
import re

from candidate25 import IDS, GateError, write
from emulator_sdk25 import qa_guard

MODE = 'REQUESTED_OFFICIAL_SKIA_SOFTWARE_IMPELLER_OFF'
READBACK = 'NOT_READ_BACK_NO_BACKEND_CLAIM'
FLAGS = ('--ez','enable-software-rendering','true','--ez','enable-impeller','false')
RECEIPT = 'FLUTTER_GRAPHICS_REQUEST_25.json'


def observed_software_adb(original, package, out):
    enabled = os.environ.get('TASK25_SOFTWARE_GRAPHICS', 'false')
    if enabled == 'false':
        return original
    if enabled != 'true':
        raise GateError('EXPLICIT_SOFTWARE_TEST_PROFILE_REQUIRED')
    root = qa_guard()
    if package not in IDS.values() or Path(out) != root / 'task25-native-evidence':
        raise GateError('EXACT_CONTROLLED_PACKAGE_AND_OUTPUT_REQUIRED')
    if original('shell','getprop','ro.kernel.qemu').strip() != '1':
        raise GateError('SOFTWARE_PROFILE_DISPOSABLE_EMULATOR_ONLY')
    out = Path(out)
    out.mkdir(exist_ok=True)
    receipt = out / RECEIPT
    if receipt.exists():
        raise GateError('FRESH_GRAPHICS_REQUEST_RECEIPT_REQUIRED')
    proof = {'mode':MODE,'package':package,'engineStateReadback':READBACK,
             'APKChanged':False,'originalUIAndDataChecksRetained':True,'launches':[]}
    expected = ('shell','am','start','-W','-n',package+'/ru.sulfi.sulfi_hypnotherapy.MainActivity')

    def adb(*args, **kwargs):
        if args != expected:
            return original(*args, **kwargs)
        result = original(*args, *FLAGS, **kwargs)  # Exactly one original launch.
        if not isinstance(result,str) or not re.search(r'\bStatus:\s*ok\b',result):
            raise GateError('OFFICIAL_GRAPHICS_LAUNCH_NOT_ACKNOWLEDGED')
        package_info = original('shell','dumpsys','package',package)
        version = re.search(r'\bversionCode=(28|29)\b',package_info)
        if not version:
            raise GateError('EXACT_NATIVE28_OR29_GRAPHICS_SCOPE_REQUIRED')
        proof['launches'].append({'versionCode':int(version[1]),'flags':list(FLAGS),
                                  'amStartAcknowledged':True})
        write(receipt, proof)
        return result
    return adb


def request_proof(root, package):
    path = Path(root) / 'task25-native-evidence' / RECEIPT
    if path.is_symlink() or not path.is_file():
        raise GateError('OFFICIAL_GRAPHICS_REQUEST_RECEIPT_REQUIRED')
    proof = json.loads(path.read_text())
    if not valid_proof(proof,package):
        raise GateError('OFFICIAL_GRAPHICS_REQUEST_RECEIPT_INVALID')
    return proof


def valid_proof(proof,package):
    launches = proof.get('launches',[])
    return (proof.get('mode') == MODE and proof.get('package') == package and package in IDS.values()
            and proof.get('engineStateReadback') == READBACK and proof.get('APKChanged') is False
            and proof.get('originalUIAndDataChecksRetained') is True
            and len(launches) >= 4
            and all(type(r.get('versionCode')) is int and r['versionCode'] in {28,29}
                    and r.get('flags') == list(FLAGS) and r.get('amStartAcknowledged') is True for r in launches)
            and all(sum(r.get('versionCode')==v for r in launches)>=2 for v in [28,29]))
