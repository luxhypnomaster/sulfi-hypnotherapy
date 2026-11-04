import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/diary_repository.dart';
import 'services/diary_api.dart';
import 'services/diary_controller.dart';
import 'services/diary_identity.dart';
import 'services/apps_script_diary_transport.dart';
import 'data/library_repository.dart';
import 'data/session_repository.dart';
import 'data/module_catalog.dart';
import 'services/session_audio_handler.dart';

import 'package:audio_service/audio_service.dart';

import 'services/session_controller.dart';
import 'services/library_service.dart';
import 'services/preview_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  LibraryService? _library;
  LocalPreviewPlayer? _player;
  SqliteLibraryRepository? _repository;
  SessionController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    setState(() => _failed = false);
    try {
      final root = await getApplicationSupportDirectory();
      await root.create(recursive: true);
      final repository = await SqliteLibraryRepository.open(
        p.join(root.path, 'library.sqlite'),
      );
      _repository = repository;
      final sessions = SqliteSessionRepository(repository.database);
      final modules = ModuleCatalog(repository.database);
      final library = LibraryService(
        repository: repository,
        directory: Directory(p.join(root.path, 'audio')),
        pick: () async {
          final selected = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['mp3', 'm4a', 'wav'],
          );
          if (selected == null) return null;
          final path = selected.path;
          if (path == null) {
            throw const LibraryException(
              'Файл недоступен. Сохраните его на устройство и повторите выбор.',
            );
          }
          return (name: selected.name, path: path);
        },
        probe: (path) async {
          final probe = AudioPlayer(
            handleInterruptions: false,
            handleAudioSessionActivation: false,
          );
          try {
            return await probe
                .setFilePath(path)
                .timeout(const Duration(seconds: 25));
          } finally {
            await probe.dispose();
          }
        },
        releaseSelection: FilePicker.clearTemporaryFiles,
        references: (id) async => [
          ...await sessions.references(id),
          ...await modules.references(id),
        ],
        resetRelatedData: () async {
          await modules.clear();
          await sessions.reset();
        },
      );
      await library.initialize();
      await FilePicker.clearTemporaryFiles();
      final player = LocalPreviewPlayer();
      _player = player;
      await player.initialize();
      const diaryUrl = String.fromEnvironment('SULFI_DIARY_API');
      const googleClientId = String.fromEnvironment(
        'SULFI_GOOGLE_WEB_CLIENT_ID',
      );
      final diaryBase = diaryUrl.isEmpty ? null : Uri.parse(diaryUrl);
      final diary = DiaryController(
        DiaryRepository(repository.database),
        api: diaryBase == null
            ? null
            : DiaryApi(
                diaryBase,
                request: AppsScriptDiaryTransport.supports(diaryBase)
                    ? AppsScriptDiaryTransport(diaryBase).request
                    : null,
              ),
        authorRepository: DiaryAuthorRepository(repository.database),
        identity: GoogleDiaryIdentity(serverClientId: googleClientId),
      );
      await diary.load();
      if (diary.api != null) unawaited(diary.sync());
      final controller = SessionController(
        repository: sessions,
        library: library,
        modules: modules,
        diary: diary,
      );
      _controller = controller;
      await controller.initialize();
      sessionAudioHandler = await AudioService.init<SessionAudioHandler>(
        builder: () => SessionAudioHandler(controller),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'ru.sulfi.sessions',
          androidNotificationChannelName: 'Сессия самогипноза',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
        ),
      );
      if (mounted) setState(() => _library = library);
    } catch (_) {
      await _player?.close();
      _controller?.dispose();
      _controller = null;
      await _repository?.database.close();
      _player = null;
      _repository = null;
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(_player?.close());
    unawaited(_repository?.database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_library case final LibraryService library) {
      return SulfiApp(
        library: library,
        player: _player!,
        controller: _controller!,
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: sulfiTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Не удалось открыть приложение. Проверьте свободное место и повторите попытку. Данные не сброшены.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _initialize,
                          child: const Text('Повторить'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}
