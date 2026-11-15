import '../services/alchemist_work_queue.dart';
import '../services/native_transfer_bridge.dart';

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
    _poll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(readNativeState()),
    );
  }

  Timer? _poll;
  bool _reading = false;
  Future<void> readNativeState() async {
    if (_reading || !mounted) return;
    _reading = true;
    try {
      await widget.controller.cloudQueue.refresh();
      if (NativeTransferBridge.available) {
        final status = await NativeTransferBridge.channel
            .invokeMapMethod<String, dynamic>('status');
        if (mounted && status?['openQueue'] == true) {
          widget.navigatorKey.currentState?.push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  AlchemistSyncScreen(controller: widget.controller),
            ),
          );
        }
      }
    } catch (_) {
      /* no fabricated completion; saved queue remains */
    } finally {
      _reading = false;
    }
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
    // Execution belongs to Android, never convert Home/lock into user pause.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _poll?.cancel();
    }
    if (state == AppLifecycleState.resumed) {
      widget.controller.cloudQueue.foreground();
      _poll?.cancel();
      _poll = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(readNativeState()),
      );
      unawaited(readNativeState());
      unawaited(
        widget.controller.diary?.restoreSignIn() ?? Future<void>.value(),
      );
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.policy.removeListener(identityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller.cloudQueue,
    builder: (context, _) {
      final queue = widget.controller.cloudQueue;
      if (queue.pendingCount == 0) {
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
                  const Icon(Icons.sync, size: 18, color: transferYellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Передачи: ${queue.pendingCount} · ${alchemistStageLabel(queue.rows.where((r) => !const ['complete', 'cancelled'].contains(r['_work']?['phase'])).firstOrNull?['_work']?['stage'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: transferYellow,
                      ),
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
