import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/event_marker_catalog.dart';
import '../../services/api_client.dart';
import '../event_marker_widget.dart';
import 'detail_edit_payload.dart';

class DetailEditSheet extends StatefulWidget {
  const DetailEditSheet({
    super.key,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialImageUrl,
    required this.initialColor,
    required this.initialIcon,
    required this.onSave,
  });

  final String initialTitle;
  final String initialDescription;
  final String? initialImageUrl;
  final Color initialColor;
  final IconData initialIcon;
  final Function(DetailEditPayload) onSave;

  @override
  State<DetailEditSheet> createState() => _DetailEditSheetState();
}

class _DetailEditSheetState extends State<DetailEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late Color _selectedColor;
  late IconData _selectedIcon;
  late List<IconData> _icons;

  String? _localImagePath;
  bool _removeImage = false;
  bool _photoBusy = false;

  static const Color _text = Color(0xFFDFE3EC);
  static const Color _subtitle = Color(0xFFB5BBC7);
  static const Color _cardBorder = Color(0xFF23262C);
  static const Color _notGoingBg = Color(0xFF36D3F0);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _selectedColor = widget.initialColor;
    _selectedIcon = widget.initialIcon;

    // Загрузка доступных иконок
    // В реальном приложении нужно получать статус пользователя
    _icons = EventMarkerCatalog.availableIconsForUserStatus(1);
    if (_icons.isEmpty) {
      _icons = EventMarkerCatalog.availableIconsForUserStatus(1);
    }
  }

  bool get _hasExistingServerImage =>
      (ApiClient.getFullImageUrl(widget.initialImageUrl) ?? '').trim().isNotEmpty;

  bool get _hasAnyImageNow =>
      (_localImagePath != null) || (_hasExistingServerImage && !_removeImage);

  Future<void> _pickNewImage() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (xfile == null || !mounted) return;
      setState(() {
        _localImagePath = xfile.path;
        _removeImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выбрать изображение')),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _removeImageLocal() {
    setState(() {
      _localImagePath = null;
      _removeImage = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EventMarkerWidget(
                      color: _selectedColor,
                      icon: _selectedIcon,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Редактирование события',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Фото',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: _localImagePath != null
                        ? Image.file(
                            File(_localImagePath!),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF141414),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          )
                        : (_hasExistingServerImage && !_removeImage)
                            ? Image.network(
                                ApiClient.getFullImageUrl(widget.initialImageUrl)!,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFF141414),
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFF141414),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _photoBusy ? null : _pickNewImage,
                        icon: _photoBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: Text(_hasAnyImageNow ? 'Изменить' : 'Добавить'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_hasAnyImageNow && !_photoBusy)
                            ? _removeImageLocal
                            : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Удалить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5F57),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Название',
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    labelStyle: const TextStyle(color: _subtitle),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _notGoingBg.withOpacity(0.9),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Описание',
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    labelStyle: const TextStyle(color: _subtitle),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _notGoingBg.withOpacity(0.9),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Цвет',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EventMarkerCatalog.availableColors.map((c) {
                    final selected = c.toARGB32() == _selectedColor.toARGB32();
                    return InkWell(
                      onTap: () => setState(() => _selectedColor = c),
                      borderRadius: BorderRadius.circular(999),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: c,
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Иконка',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _icons.map((i) {
                    final selected = i.codePoint == _selectedIcon.codePoint;
                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = i),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(i),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _notGoingBg,
                      foregroundColor: const Color(0xFF021018),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Введите название')),
                        );
                        return;
                      }

                      widget.onSave(
                        DetailEditPayload(
                          title: title,
                          description: _descriptionController.text.trim(),
                          markerColorValue: _selectedColor.toARGB32(),
                          markerIconCodePoint: _selectedIcon.codePoint,
                          localImagePath: _localImagePath,
                          removeImage: _removeImage && _localImagePath == null,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
