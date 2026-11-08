#!/usr/bin/env python3
"""Read-only APK comparison. Device installation remains a separate check."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('previous', type=Path)
parser.add_argument('candidate', type=Path)
parser.add_argument('--sdk', type=Path, default=Path(os.environ.get('ANDROID_HOME', '/workspace/tools/android-sdk')))
args = parser.parse_args()
build_tools = sorted((args.sdk / 'build-tools').iterdir(), key=lambda p: [int(x) for x in re.findall(r'\d+', p.name)])[-1]

def inspect(apk):
    certs = subprocess.check_output([str(build_tools / 'apksigner'), 'verify', '--print-certs', str(apk)], text=True)
    badging = subprocess.check_output([str(build_tools / 'aapt'), 'dump', 'badging', str(apk)], text=True)
    package = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not package:
        raise ValueError('Cannot read Android package metadata')
    fingerprints = sorted(re.findall(r'Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)', certs))
    if not fingerprints:
        raise ValueError('No verified signing certificate')
    return {'applicationId': package[1], 'versionCode': int(package[2]), 'versionName': package[3], 'certificateSha256': fingerprints}

previous, candidate = inspect(args.previous), inspect(args.candidate)
checks = {'sameApplicationId': previous['applicationId'] == candidate['applicationId'],
          'sameSigningCertificates': previous['certificateSha256'] == candidate['certificateSha256'],
          'increasedVersionCode': candidate['versionCode'] > previous['versionCode']}
print(json.dumps({'previous': previous, 'candidate': candidate, 'checks': checks,
                  'metadataCompatible': all(checks.values()),
                  'deviceInstallVerified': False}, ensure_ascii=False, indent=2))
raise SystemExit(0 if all(checks.values()) else 1)
