#!/usr/bin/env python3
"""Independent read-only delivery gate over actual native artifacts, never OWNER QA."""
import argparse
import json
from pathlib import Path

from candidate25 import SOURCE, CODE

TABLES = ('audio_assets', 'module_definitions', 'session_templates', 'current_draft',
          'session_runs', 'run_events', 'diary_author', 'diary_public', 'app_settings',
          'content_revisions', 'history_attachments', 'capsule_imports',
          'legacy_v2_documents', 'diary_sync', 'diary_removed')
BASE_CASES = {'install_actual28', 'ui_audio_1', 'ui_audio_2', 'ui_audio_3',
              'ui_module_three_tracks', 'ui_module_pause', 'ui_program', 'ui_history',
              'native_queue_cache_settings_supplement', 'ui_capsule_export',
              'beforeBaseline', 'normal_install_r_28_to29', 'UI_after29_and_native_audio',
              'cold_restart29', 'offline_diary_reader29'}
REQUIRED_NATIVE_SCOPES = {('master',34),('client',34),('master',36),('client',36)}


def inspect(report, driver_sha):
    errors = []
    def require(ok, code):
        if not ok: errors.append(code)
    edition, api = report.get('edition'), report.get('api')
    require(edition in ('master', 'client') and api in (34, 36), 'EDITION_API_SCOPE')
    require(report.get('applicationSourceSHA') == SOURCE, 'APPLICATION_SOURCE')
    require(report.get('driverMainSHA') == driver_sha, 'TRUSTED_DRIVER_SOURCE')
    require(report.get('baseline') == 28 and report.get('candidate') == CODE, 'VERSION_SCOPE')
    require(report.get('ownerPhone') == 'NOT_TOUCHED' and report.get('realGoogle') == 'NOT_RUN', 'NO_OWNER_OR_GOOGLE_PASS_CLAIM')
    require(report.get('uninstallClearDowngrade') is False and report.get('newKeysGenerated') is False, 'NO_DESTRUCTIVE_OR_NEW_KEY_ACTIONS')
    cases = report.get('cases', [])
    names = [c.get('case') for c in cases]
    required = BASE_CASES | ({'ui_master_local_diary28', 'ui_master_local_diary29'} if edition == 'master' else set())
    require(len(names) == len(set(names)) and set(names) == required, 'COMPLETE_UNIQUE_CASES')
    require(bool(cases) and all(c.get('status') == 'PASS' for c in cases), 'ALL_CASES_PASS')
    by_name = {c.get('case'): c for c in cases}
    require(by_name.get('UI_after29_and_native_audio', {}).get('details', {}).get('nativeLibraryAudioObserved') is True, 'REAL_NATIVE_AUDIO_OBSERVED')
    require(by_name.get('offline_diary_reader29', {}).get('details', {}).get('cachePreservedAndReadableOffline') is True, 'OFFLINE_CACHE_READABLE')
    inv = report.get('inventories', {})
    before = inv.get('beforeBaseline', {})
    rows = before.get('rows', {})
    require(before.get('package', {}).get('versionCode') == 28, 'ACTUAL_BASELINE28')
    for table, minimum in [('audio_assets',3), ('module_definitions',2), ('session_templates',1),
                           ('current_draft',1), ('session_runs',1), ('diary_public',1)]:
        require(len(rows.get(table, [])) >= minimum, 'NONEMPTY_UI_BASELINE_' + table)
    if edition == 'master': require(bool(rows.get('diary_author')), 'MASTER_OLD_LOCAL_DRAFT')
    require(len({a.get('contentHash') for a in rows.get('audio_assets', [])}) >= 3, 'DISTINCT_AUDIO_BYTES')
    require(any(r.get('name') == 'transfer_network_policy18' for r in rows.get('app_settings', [])), 'PERSISTENT_SETTINGS_BASELINE')
    require(any(p.startswith('external/') for p in before.get('files', {})), 'EXISTING_UI_CAPSULE')
    for label in ('afterCandidate', 'coldCandidate'):
        after = inv.get(label, {})
        require(after.get('package', {}).get('versionCode') == CODE, 'ACTUAL29_' + label)
        require(after.get('database') == before.get('database') == {'integrity':'ok','version':9}, 'SQLITE_INTEGRITY_' + label)
        for table in TABLES:
            require(table in rows and table in after.get('rows', {}), 'TABLE_PRESENT_' + label + '_' + table)
            require(all(r in after.get('rows', {}).get(table, []) for r in rows.get(table, [])), 'EXACT_OLD_ROWS_' + label + '_' + table)
        for path, value in before.get('files', {}).items():
            if path.startswith(('files/audio/', 'files/diary_media/', 'files/history_media/', 'external/')):
                require(after.get('files', {}).get(path) == value, 'EXACT_OLD_MEDIA_' + label + '_' + path)
    return {'edition': edition, 'api': api, 'status':'PASS_CONTROLLED_NATIVE' if not errors else 'BLOCKED',
            'cases': len(cases), 'errors': errors}


def validate(reports, driver_sha):
    values = [inspect(r, driver_sha) for r in reports]
    dimensions = [(r['edition'], r['api']) for r in values]
    complete = len(dimensions) == 4 and set(dimensions) == REQUIRED_NATIVE_SCOPES
    passed = complete and all(r['status'] == 'PASS_CONTROLLED_NATIVE' for r in values)
    return {'status':'PASS_FOUR_NATIVE_DELIVERY_GATES' if passed else 'BLOCKED_NATIVE_DELIVERY',
            'scope':'CONTROLLED_ANDROID_EMULATORS_ONLY', 'ownerPhone':'NOT_RUN', 'realGoogle':'NOT_RUN',
            'applicationSourceSHA':SOURCE, 'driverMainSHA':driver_sha, 'completeFourGates':complete,
            'requiredScopes':sorted(REQUIRED_NATIVE_SCOPES),
            'totalCases':sum(r['cases'] for r in values), 'reports':values}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--driver-sha', required=True)
    p.add_argument('reports', nargs='+', type=Path)
    args = p.parse_args()
    result = validate([json.loads(f.read_text()) for f in args.reports], args.driver_sha)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'] == 'PASS_FOUR_NATIVE_DELIVERY_GATES' else 1


if __name__ == '__main__': raise SystemExit(main())
