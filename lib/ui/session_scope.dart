import 'package:flutter/widgets.dart';

import '../services/session_controller.dart';
import '../services/preview_player.dart';

/// Shared existing session/library and preview engine for nested diary routes.
class SessionScope extends InheritedWidget {
  const SessionScope({
    super.key,
    required this.controller,
    required this.player,
    required super.child,
  });
  final SessionController controller;
  final PreviewPlayer player;
  static SessionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>();
  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      oldWidget.controller != controller || oldWidget.player != player;
}
