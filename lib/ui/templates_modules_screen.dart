import 'package:flutter/material.dart';

import '../services/preview_player.dart';
import '../services/session_controller.dart';
import 'design.dart';
import 'modules_screen.dart';
import 'templates_screen.dart';

class TemplatesModulesScreen extends StatelessWidget {
  const TemplatesModulesScreen({
    super.key,
    required this.controller,
    required this.player,
  });
  final SessionController controller;
  final PreviewPlayer player;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: LeatherScaffold(
      title: 'Программы и модули',
      child: Column(
        children: [
          const TabBar(
            indicatorColor: neonLime,
            labelColor: neonLime,
            tabs: [
              Tab(text: 'Программы'),
              Tab(text: 'Модули'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                TemplatesScreen(
                  controller: controller,
                  player: player,
                  embedded: true,
                ),
                ModulesScreen(
                  controller: controller,
                  player: player,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
