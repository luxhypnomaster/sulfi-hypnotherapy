import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';

import '../models/audio_asset.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import '../services/recorder_service.dart';
import '../services/session_audio_handler.dart';
import '../models/local_dates.dart';
import 'design.dart';
import 'module_assignment.dart';
import '../models/diary_entry.dart';
import '../services/device_files.dart';
import '../services/library_service.dart';
import 'recorder_microphone.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({
    super.key,
    required this.controller,
    required this.player,
    this.backend,
    this.diaryRecording = false,
    this.attachDiaryBlock,
  });
  final SessionController controller;
  final PreviewPlayer player;
  final CaptureBackend? backend;
  final bool diaryRecording;
  final Future<DiaryBlock> Function(DiaryBlock)? attachDiaryBlock;
  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen>
    with WidgetsBindingObserver {
  late final r = RecorderService(
    backend: widget.backend ?? NativeCaptureBackend(),
    library: widget.controller.library,
    tempDirectory: Directory(
      '${widget.controller.library.directory.parent.path}/recordings_temp',
    ),
  );
  final _form = GlobalKey<FormState>();
  late final _initialTitle =
      "Личная запись · ${localDateLabel(DateTime.now())}";
  late final _title = TextEditingController(text: _initialTitle);
  final _description = TextEditingController(), _tags = TextEditingController();
  final _choice = ModuleChoice();
  AudioCategory _category = AudioCategory.freeform;
  bool _allowPop = false;
  bool _awake = false;
  void _wake() {
    final awake = r.state == CaptureState.recording;
    if (_awake == awake) return;
    _awake = awake;
    unawaited(DeviceFiles.keepAwake(awake));
  }

  StreamSubscription<dynamic>? _focus;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    r.addListener(_wake);
    unawaited(Future.microtask(_initialize));
  }

  Future<void> _begin() async {
    if (sessionAudioHandler?.engine?.active ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала завершите активную сессию. Запись одновременно с ней не запускается.',
          ),
        ),
      );
      return;
    }
    await r.start();
  }

  Future<void> _initialize() async {
    await widget.player.stop();
    if (widget.backend != null) return;
    final session = await AudioSession.instance;
    if (!mounted) return;
    _focus = session.interruptionEventStream.listen((e) {
      if (e.begin) unawaited(r.interrupt());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) {
      unawaited(widget.player.stop());
      unawaited(r.interrupt());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    r.removeListener(_wake);
    unawaited(DeviceFiles.keepAwake(false));
    unawaited(_focus?.cancel());
    unawaited(Future.microtask(widget.player.stop));
    unawaited(r.close());
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (r.busy) return;
    if ((r.hasTake ||
            _title.text != _initialTitle ||
            _description.text.isNotEmpty ||
            _tags.text.isNotEmpty) &&
        !await confirmAction(
          context,
          'Отменить и удалить несохранённую запись?',
          widget.diaryRecording
              ? 'Текст и сохранённые вложения дневника останутся.'
              : 'Сохранённые треки библиотеки останутся.',
          confirm: 'Отменить запись',
        )) {
      return;
    }
    await widget.player.stop();
    await r.discard();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (!await confirmAction(
      context,
      'Удалить несохранённый дубль?',
      'Параметры трека останутся, можно записать заново.',
      confirm: 'Удалить дубль',
    )) {
      return;
    }
    await widget.player.stop();
    await r.discard();
  }

  Future<void> _preview() async {
    try {
      final f = File(r.path!);
      final a = AudioAsset(
        id: 'unsaved-take',
        title: _title.text.isEmpty ? 'Несохранённая запись' : _title.text,
        filePath: 'take.m4a',
        durationMs: r.duration.inMilliseconds,
        format: 'm4a',
        createdAt: DateTime.now(),
        category: _category,
        fileSizeBytes: await f.length(),
      );
      await widget.player.toggle(a, f);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прослушать дубль.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await widget.player.stop();
    if (!mounted) return;
    if (widget.diaryRecording) {
      final store = widget.controller.diary?.mediaStore;
      if (store == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Хранилище дневника недоступно. Дубль сохранён до выхода.',
            ),
          ),
        );
        return;
      }
      final title = _title.text.trim().isEmpty
          ? _initialTitle
          : _title.text.trim();
      final block = await r.saveTo((path) async {
        final copied = (await store.importFile(DiaryBlockType.audio, (
          name: '$title.m4a',
          path: path,
        ))).copyWith(label: title);
        try {
          // The raw take is removed by saveTo only AFTER the entry's SQLite
          // attachment commit succeeds. A failed commit remains retryable.
          return await widget.attachDiaryBlock?.call(copied) ?? copied;
        } catch (_) {
          throw const LibraryException(
            'Не удалось прикрепить аудио к дневнику. Дубль сохранён временно; повторите добавление.',
          );
        }
      });
      if (block != null && mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, block);
      }
      return;
    }
    final asset = await r.save(
      _title.text,
      _category,
      description: _description.text,
      tags: _tags.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    if (asset == null || !mounted) return;
    try {
      await attachAudioToModule(widget.controller.modules, _choice, asset);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Трек сохранён в библиотеке. Связь с модулем не сохранена.',
            ),
          ),
        );
      }
    }
    await widget.controller.reload();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context, asset);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (p, _) {
      if (!p) unawaited(_cancel());
    },
    child: ListenableBuilder(
      listenable: Listenable.merge([r, widget.player]),
      builder: (context, _) {
        final playing = widget.player.playing;
        final paused = r.state == CaptureState.paused;
        final status = switch (r.state) {
          CaptureState.idle => 'Готово к записи',
          CaptureState.requestingPermission => 'Запрос разрешения…',
          CaptureState.recording => '● Идёт запись',
          CaptureState.paused => 'Пауза записи',
          CaptureState.finished =>
            playing ? 'Прослушивание' : 'Запись завершена · можно прослушать',
          CaptureState.saving => 'Сохранение…',
          CaptureState.saved => 'Трек сохранён',
          CaptureState.error => 'Ошибка записи',
        };
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            toolbarHeight: 46,
            leading: IconButton(
              tooltip: 'Отмена',
              onPressed: _cancel,
              icon: const Icon(Icons.arrow_back),
            ),
            title: Row(
              children: [
                Image.asset('assets/brand/spiral.png', width: 36),
                const SizedBox(width: 8),
                Text(
                  widget.diaryRecording ? 'Аудио для дневника' : 'Запись трека',
                  style: const TextStyle(
                    color: neonLime,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 46 + MediaQuery.viewPaddingOf(context).top,
                  child: ExcludeSemantics(
                    child: Image.asset(
                      'assets/art/sulfi_header.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      alignment: const Alignment(1, .3),
                    ),
                  ),
                ),
                Expanded(
                  child: LeatherBoard(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.diaryRecording
                                  ? 'Аудиовложение'
                                  : 'Параметры трека',
                              style: const TextStyle(
                                color: neonLime,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextFormField(
                              controller: _title,
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: widget.diaryRecording
                                    ? 'Название (необязательно)'
                                    : 'Название трека *',
                              ),
                              validator: (v) =>
                                  !widget.diaryRecording &&
                                      (v ?? '').trim().isEmpty
                                  ? 'Введите название'
                                  : null,
                            ),
                            if (!widget.diaryRecording) ...[
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _description,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Описание',
                                ),
                                maxLines: 1,
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<AudioCategory>(
                                initialValue: _category,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Категория · Мои аудиозаписи',
                                ),
                                items: AudioCategory.values
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _category = v!),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _tags,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Теги',
                                  hintText: 'Например: мой голос, расслабление',
                                ),
                              ),
                              const SizedBox(height: 6),
                              ModuleAssignment(
                                compact: true,
                                catalog: widget.controller.modules,
                                choice: _choice,
                              ),
                            ],
                            const Divider(height: 12, color: antiqueGold),
                            const Text(
                              'Запись',
                              style: TextStyle(
                                color: neonLime,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Center(
                              child: IconButton(
                                tooltip: paused
                                    ? 'Продолжить запись'
                                    : 'Начать запись',
                                iconSize: 96,
                                padding: EdgeInsets.zero,
                                onPressed: r.busy
                                    ? null
                                    : paused
                                    ? r.resume
                                    : r.state == CaptureState.idle ||
                                          r.state == CaptureState.error &&
                                              !r.hasTake
                                    ? _begin
                                    : null,
                                icon: const RecorderMicrophone(),
                              ),
                            ),
                            LinearProgressIndicator(
                              value: r.state == CaptureState.recording
                                  ? r.level
                                  : 0,
                              color: neonPink,
                            ),
                            Center(
                              child: Text(
                                r.duration.inMilliseconds > 0 &&
                                        r.duration.inSeconds == 0
                                    ? '< 1 секунды'
                                    : formatDuration(r.duration.inMilliseconds),
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                            Center(child: Text(status)),
                            if (r.error != null)
                              Text(
                                r.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (widget.player.current?.id == 'unsaved-take')
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: widget
                                          .player
                                          .position
                                          .inMilliseconds
                                          .clamp(0, r.duration.inMilliseconds)
                                          .toDouble(),
                                      max: r.duration.inMilliseconds.toDouble(),
                                      onChanged: (v) => widget.player.seek(
                                        Duration(milliseconds: v.round()),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${formatDuration(widget.player.position.inMilliseconds)} / ${formatDuration(r.duration.inMilliseconds)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            Row(
                              children: [
                                _action(
                                  'Удалить',
                                  Icons.delete_outline,
                                  r.hasTake && !r.busy && !playing
                                      ? _delete
                                      : null,
                                ),
                                _action(
                                  playing
                                      ? 'Пауза прослушивания'
                                      : 'Воспроизвести',
                                  playing ? Icons.pause : Icons.play_arrow,
                                  r.canSave && !r.busy ? _preview : null,
                                ),
                                _action(
                                  paused ? 'Продолжить' : 'Пауза',
                                  paused ? Icons.play_arrow : Icons.pause,
                                  !r.busy && r.capturing
                                      ? (paused ? r.resume : r.pause)
                                      : null,
                                ),
                                _action(
                                  'Завершить',
                                  Icons.stop,
                                  !r.busy && r.capturing ? r.finish : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      label: 'Отмена',
                      icon: Icons.close,
                      onPressed: r.busy ? null : _cancel,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NeonButton(
                      label: widget.diaryRecording
                          ? 'Добавить в дневник'
                          : 'Сохранить трек',
                      icon: Icons.check,
                      onPressed: r.canSave && !r.busy && !playing
                          ? _save
                          : null,
                      primary: true,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  Widget _action(String label, IconData icon, VoidCallback? callback) =>
      Expanded(
        child: IconButton(
          tooltip: label,
          onPressed: callback,
          icon: Icon(icon, size: 32),
        ),
      );
}
