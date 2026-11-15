/// A user-started pre-34 dataSync service may keep a short retry window instead
/// of immediately handing a transient outage to Android's batched regular jobs.
/// It never makes a waiting job eligible sooner or changes owner/user intent.
Duration? foregroundTransferRetryDelay(
  Iterable<Map<String, dynamic>> rows, {
  required int nowMs,
  required Duration remaining,
}) {
  if (remaining <= Duration.zero) return null;
  int? earliest;
  for (final row in rows) {
    final work = row['_work'];
    if (work is! Map ||
        work['executor'] != 'android18' ||
        work['autoResume'] != true ||
        !const ['waiting_network', 'retry_scheduled'].contains(work['phase']) ||
        work['pauseReason'] == 'USER_PAUSED' ||
        work['retryAtMs'] is! int) {
      continue;
    }
    final due = work['retryAtMs'] as int;
    if (earliest == null || due < earliest) earliest = due;
  }
  if (earliest == null) return null;
  final delay = Duration(milliseconds: (earliest - nowMs).clamp(1, 900000));
  // Do not reset/bypass the existing durable backoff to fit this window.
  return delay <= remaining ? delay : null;
}
