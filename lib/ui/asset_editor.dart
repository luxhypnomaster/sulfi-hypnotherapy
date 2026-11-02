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
  late AudioCategory _category = widget.asset.category;

  @override
  void dispose() {
    _title.dispose();
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
            Navigator.pop(context, widget.asset.edited(_title.text, _category));
          }
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}
