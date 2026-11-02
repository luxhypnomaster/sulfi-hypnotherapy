import 'package:flutter/material.dart';

import '../models/audio_asset.dart';

Future<AudioAsset?> editAsset(BuildContext context, AudioAsset asset) =>
    showDialog<AudioAsset>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssetEditor(asset: asset),
    );

class _AssetEditor extends StatefulWidget {
  const _AssetEditor({required this.asset});
  final AudioAsset asset;
  @override
  State<_AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends State<_AssetEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.asset.title);
  late final _description = TextEditingController(
    text: widget.asset.description,
  );
  late final _tags = TextEditingController(text: widget.asset.tags.join(', '));
  late LibrarySection _section = widget.asset.section;
  late AudioCategory _category = widget.asset.category;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Аудиозапись'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.asset.format.toUpperCase()} · ${formatDuration(widget.asset.durationMs)}',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите название'
                    : value.trim().length > 120
                    ? 'Не больше 120 символов'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LibrarySection>(
                initialValue: _section,
                decoration: const InputDecoration(
                  labelText: 'Раздел библиотеки',
                ),
                isExpanded: true,
                items: LibrarySection.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
                onChanged: (s) {
                  if (s != null) setState(() => _section = s);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AudioCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Категория'),
                isExpanded: true,
                items: AudioCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLength: 2000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Описание'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tags,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Метки через запятую',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              widget.asset.edited(
                _title.text,
                _category,
                description: _description.text.trim(),
                section: _section,
                tags: _tags.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList(),
              ),
            );
          }
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}
