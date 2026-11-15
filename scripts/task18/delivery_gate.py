"""Fail closed on incomplete, modified, mixed-source or mismatched native proof."""
import hashlib
import json

UPGRADE = {
    'install_baseline', 'ui_import_1', 'ui_import_2', 'ui_import_3',
    'ui_module_elman', 'ui_module_pause', 'ui_template', 'ui_history',
    'native_controlled_old27_queue_seed', 'beforeBaseline_inventory',
    'native_update_to28', 'ui_afterCandidate', 'cold_restart28',
}
PROBE = {
    'master_install_disposable_probe', 'client_install_disposable_probe',
    'master_real_tcp_bytes_after_UI_engine_destroy_and_screen_off',
    'non_owning_recovery_watchdog_does_not_stop_primary',
    'master_notification_pause_cold_restart_explicit_same_owner_resume',
    'master_confirmed_unique_program_publication',
    'client_real_tcp_bytes_after_UI_engine_destroy_and_screen_off',
    'client_network_OS_recovery_notification_cancel_exact_range_resume',
    'client_background_atomic_program_install_3_real_wav_files_hashes_module_template',
    'client_cold_offline_3_hash_program_and_native_UID_bound_audio',
}


def validate_receipt(key, item, source, root):
    relative = item['receipt']
    path = (root / relative).resolve()
    assert relative.startswith('reports/task18/') and path.is_relative_to(
        (root / 'reports/task18').resolve()), 'UNSAFE_RECEIPT_PATH'
    data = path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == item['receiptSHA256'], 'RECEIPT_BYTES_CHANGED'
    receipt = json.loads(data)
    assert receipt.get('source', receipt.get('appSource')) == source, 'RECEIPT_SOURCE_MISMATCH'
    assert receipt['driverSource'] == item['driverSource'], 'RECEIPT_DRIVER_MISMATCH'
    cases = receipt['cases']
    assert cases and all(c['status'] == 'PASS' for c in cases), 'FAILED_OR_EMPTY_RECEIPT'
    names = [c['case'] for c in cases]
    assert len(set(names)) == len(names), 'DUPLICATE_RECEIPT_CASE'
    if key.endswith('_upgrade'):
        edition = key.removesuffix('_upgrade')
        required = UPGRADE | ({'ui_baseline_local_draft27', 'local_draft_after28'} if edition == 'master' else set())
        assert receipt['baseline'] == 27 and receipt['target'] == 28 and receipt['edition'] == edition, 'WRONG_UPGRADE'
        assert item['job'] == 'native18 (' + edition + ')', 'WRONG_UPGRADE_JOB'
    else:
        assert key in {'api33', 'api34', 'api35', 'api36'} and item['job'] == 'probe18', 'WRONG_NATIVE_JOB'
        required = PROBE | ({'master_actual_SIGKILL_cold_OS_recovery_preserves_request_and_source'} if key == 'api34' else set())
    assert set(names) == required, 'MISSING_OR_UNREVIEWED_NATIVE_CASE'
    return receipt
