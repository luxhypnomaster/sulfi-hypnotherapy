import 'dart:convert';

import 'data/alchemist_diary_repository.dart';
import 'services/alchemist_diary_api.dart';
import 'ui/diary_video.dart';

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'services/diary_media_store.dart';
import 'services/diary_audio.dart';
import 'models/diary_entry.dart';

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
import 'services/capsule_service.dart';
import 'services/device_files.dart';
import 'services/access_policy.dart';
import 'services/history_attachments.dart';
import 'services/preview_diary_transport.dart';

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
      final cache = await getTemporaryDirectory();
      await CapsuleService.cleanWorkspace(cache);
      final capsuleWorkspace = Directory(p.join(cache.path, 'sulfi-capsules'));
      await CapsuleService.cleanWorkspace(capsuleWorkspace);
      final repository = await SqliteLibraryRepository.open(
        p.join(root.path, 'library.sqlite'),
      );
      _repository = repository;
      final policy = AccessPolicy(database: repository.database);
      await policy.load();
      final sessions = SqliteSessionRepository(repository.database, policy);
      final modules = ModuleCatalog(repository.database, policy);
      final library = LibraryService(
        repository: repository,
        policy: policy,
        externalReader: (uri) async => (await DeviceFiles.channel
            .invokeMethod<String>('copyLegacyAudio', uri))!,
        directory: Directory(p.join(root.path, 'audio')),
        pick: () async {
          final selected = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
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
      player.sessionActive = () => sessionAudioHandler?.engine?.active ?? false;
      await player.initialize();
      const diaryUrl = String.fromEnvironment('SULFI_DIARY_API');
      const googleClientId = String.fromEnvironment(
        'SULFI_GOOGLE_WEB_CLIENT_ID',
      );
      final diaryBase = diaryUrl.isEmpty ? null : Uri.parse(diaryUrl);
      final diaryMedia = DiaryMediaStore(
        Directory(p.join(root.path, 'diary_media')),
        pick: (type) async {
          final selected = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: type == DiaryBlockType.image
                ? ['jpg', 'jpeg', 'png', 'webp']
                : type == DiaryBlockType.video
                ? ['mp4', 'mov', 'm4v', 'webm']
                : ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
          );
          if (selected == null) return null;
          if (selected.path == null) {
            throw const FormatException(
              'Файл недоступен. Сохраните его на телефон и повторите.',
            );
          }
          return (name: selected.name, path: selected.path!);
        },
        probe: library.probe,
        videoProbe: probeDiaryVideo,
      );
      final capsules = CapsuleService(
        database: repository.database,
        library: library,
        diaryDirectory: diaryMedia.directory,
        workspace: capsuleWorkspace,
        availableBytes: DeviceFiles.freeBytes,
        videoProbe: probeDiaryVideo,
      );
      const alchemistUrl = String.fromEnvironment('SULFI_ALCHEMIST_API');
      final newDiaryApi = alchemistUrl.isEmpty
          ? null
          : AlchemistDiaryApi(
              Uri.parse(alchemistUrl),
              capsules: capsules,
              media: diaryMedia,
            );
      if (newDiaryApi != null) {
        diaryMedia.remoteResolver = newDiaryApi.resolveMedia;
      }
      final diary = DiaryController(
        newDiaryApi == null
            ? DiaryRepository(repository.database)
            : AlchemistDiaryRepository(
                repository.database,
                scope: () => newDiaryApi.readerScope,
              ),
        policy: policy,
        api:
            newDiaryApi ??
            (diaryBase == null
                ? null
                : DiaryApi(
                    diaryBase,
                    request: AppsScriptDiaryTransport.supports(diaryBase)
                        ? AppsScriptDiaryTransport(diaryBase).request
                        : null,
                  )),
        authorRepository: DiaryAuthorRepository(repository.database),
        identity: GoogleDiaryIdentity(serverClientId: googleClientId),
        mediaStore: diaryMedia,
        allowDebugAuthor: kDebugMode,
        audioFactory: () {
          final audio = DiaryAudio(
            transport: PreviewDiaryTransport(player),
            store: diaryMedia,
            sessionActive: () => sessionAudioHandler?.engine?.active ?? false,
          );
          unawaited(audio.initializeFocus());
          return audio;
        },
      );
      await diary.load();
      // Startup only: include private drafts even while logged out. Never run
      // collection during imports/Undo, and never touch the personal audio dir.
      final allDiaryEntries = [
        ...await diary.authorRepository!.entries(),
        ...await diary.repository.published(),
      ];
      var privateCacheValid = true;
      for (final row in await repository.database.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['alchemist_private_entry:%'],
      )) {
        try {
          final value = jsonDecode(row['value'] as String);
          allDiaryEntries.add(
            DiaryEntry.fromMap(Map<String, dynamic>.from(value['entry'])),
          );
        } catch (_) {
          privateCacheValid = false;
        }
      }
      if (privateCacheValid &&
          diary.authorRepository!.invalidIds.isEmpty &&
          diary.repository.invalidIds.isEmpty) {
        final coverRows = await repository.database.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_card:%'],
        );
        final coverPaths = <String>{};
        var coversValid = true;
        for (final row in coverRows) {
          try {
            final cover = jsonDecode(row['value'] as String)['localCover'];
            if (cover is Map) {
              final file = diaryMedia.file(
                DiaryMedia.fromMap(Map<String, dynamic>.from(cover)),
              );
              if (file != null) coverPaths.add(file.path);
            }
          } catch (_) {
            coversValid = false;
          }
        }
        if (coversValid) {
          await diaryMedia.collect({
            ...coverPaths,
            for (final e in allDiaryEntries)
              for (final b in e.blocks)
                if (diaryMedia.file(b.media)?.path case final String path) path,
          });
        }
      }
      if (diary.api != null) unawaited(diary.sync());
      final historyMedia = DiaryMediaStore(
        Directory(p.join(root.path, 'history_media')),
        stripImageMetadata: true,
        videoProbe: probeDiaryVideo,
        pick: diaryMedia.pick,
        probe: library.probe,
      );
      final historyAttachments = HistoryAttachments(
        repository.database,
        historyMedia,
      );
      try {
        await historyAttachments.collect();
      } catch (_) {
        /* Corrupt metadata must preserve media, not block startup. */
      }
      final controller = SessionController(
        repository: sessions,
        historyAttachments: historyAttachments,
        preview: player,
        library: library,
        modules: modules,
        diary: diary,
        capsules: capsules,
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
      unawaited(diary.restoreSignIn());
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
