import '../services/alchemist_work_queue.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/session_controller.dart';
import 'alchemist_sync_screen.dart';
import 'design.dart';

class AlchemistQueueIndicator extends StatefulWidget {
  const AlchemistQueueIndicator({
    super.key,
    required this.controller,
    required this.navigatorKey,
  });
  final SessionController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  State<AlchemistQueueIndicator> createState() =>
      _AlchemistQueueIndicatorState();
}

class _AlchemistQueueIndicatorState extends State<AlchemistQueueIndicator>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastOwner = widget.controller.catalog.api?.ownerBinding;
    widget.controller.policy.addListener(identityChanged);
    unawaited(widget.controller.cloudQueue.recover());
  }

  String? _lastOwner;
  void identityChanged() {
    final owner = widget.controller.catalog.api?.ownerBinding;
    if (owner == _lastOwner) return;
    _lastOwner = owner;
    unawaited(widget.controller.cloudQueue.recover());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.controller.cloudQueue.pauseAll());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(
        widget.controller.diary?.restoreSignIn() ?? Future<void>.value(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.policy.removeListener(identityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.cloudQueue,
    builder: (context, _) {
      final queue = widget.controller.cloudQueue;
      if (!widget.controller.policy.isAuthor || queue.pendingCount == 0) {
        return const SizedBox.shrink();
      }
      return Material(
        color: ink,
        child: SafeArea(
          bottom: false,
          child: InkWell(
            onTap: () => widget.navigatorKey.currentState?.push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    AlchemistSyncScreen(controller: widget.controller),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.sync, size: 18, color: neonPink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Передачи: ${queue.pendingCount} · ${alchemistStageLabel(queue.rows.where((r) => !const ['complete', 'cancelled'].contains(r['_work']?['phase'])).firstOrNull?['_work']?['stage'])}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
