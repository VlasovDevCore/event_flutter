import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/event_marker_catalog.dart';
import '../../services/api_client.dart';
import '../create/event_color_picker.dart';
import '../create/event_description_field.dart';
import '../create/event_icon_picker.dart';
import '../create/event_marker_preview_card.dart';
import '../create/event_title_field.dart';
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
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late Color _selectedColor;
  late IconData _selectedIcon;
  late List<IconData> _icons;

  String? _localImagePath;
  bool _removeImage = false;
  bool _photoBusy = false;

  static const Color _bg = Color(0xFF161616);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _selectedColor = widget.initialColor;
    _selectedIcon = widget.initialIcon;

    _icons = EventMarkerCatalog.availableIconsForUserStatus(1);
    if (_icons.isEmpty) {
      _icons = EventMarkerCatalog.availableIconsForUserStatus(1);
    }
  }

  bool get _hasExistingServerImage =>
      (ApiClient.getFullImageUrl(widget.initialImageUrl) ?? '')
          .trim()
          .isNotEmpty;

  bool get _hasAnyImageNow =>
      (_localImagePath != null) || (_hasExistingServerImage && !_removeImage);

  Future<void> _pickNewImage() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2000,
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
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Редактирование события',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                EventMarkerPreviewCard(
                  color: _selectedColor,
                  icon: _selectedIcon,
                ),
                const SizedBox(height: 12),

                // Фото события - в стиле CreateEventDetailsScreen
                _EventPhotoPicker(
                  path: _localImagePath,
                  existingImageUrl: _hasExistingServerImage && !_removeImage
                      ? ApiClient.getFullImageUrl(widget.initialImageUrl)
                      : null,
                  onPick: _photoBusy ? null : _pickNewImage,
                  onRemove: _removeImageLocal,
                  busy: _photoBusy,
                ),

                const SizedBox(height: 10),
                EventColorPicker(
                  selectedColor: _selectedColor,
                  onColorSelected: (color) =>
                      setState(() => _selectedColor = color),
                ),
                const SizedBox(height: 15),
                EventIconPicker(
                  icons: _icons,
                  selectedIcon: _selectedIcon,
                  onIconSelected: (icon) =>
                      setState(() => _selectedIcon = icon),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EventTitleField(controller: _titleController),
                      const SizedBox(height: 12),
                      EventDescriptionField(controller: _descriptionController),
                      const SizedBox(height: 16),
                      _SaveButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          final title = _titleController.text.trim();
                          widget.onSave(
                            DetailEditPayload(
                              title: title,
                              description: _descriptionController.text.trim(),
                              markerColorValue: _selectedColor.toARGB32(),
                              markerIconCodePoint: _selectedIcon.codePoint,
                              localImagePath: _localImagePath,
                              removeImage:
                                  _removeImage && _localImagePath == null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text(
              'Сохранить',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Виджет выбора фото в стиле CreateEventDetailsScreen
class _EventPhotoPicker extends StatelessWidget {
  const _EventPhotoPicker({
    required this.path,
    required this.existingImageUrl,
    required this.onPick,
    required this.onRemove,
    required this.busy,
  });

  final String? path;
  final String? existingImageUrl;
  final VoidCallback? onPick;
  final VoidCallback onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLocalImage = path != null && path!.isNotEmpty;
    final hasExistingImage =
        existingImageUrl != null && existingImageUrl!.trim().isNotEmpty;
    final has = hasLocalImage || hasExistingImage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: has
              ? const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: has ? null : onPick,
            splashColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: has
                              ? const Color(0xFFFEBC2F).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          has ? Icons.photo_library : Icons.add_photo_alternate,
                          size: 20,
                          color: has ? const Color(0xFFFEBC2F) : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              has ? 'Фото события' : 'Добавить фото',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            if (!has)
                              Text(
                                'Необязательно',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!has && !busy)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Выбрать',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      if (busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      if (has && !busy)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildIconButton(
                              icon: Icons.delete_outline,
                              onPressed: onRemove,
                              color: scheme.error,
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (has) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          hasLocalImage
                              ? Image.file(
                                  File(path!),
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 220,
                                        color: const Color(0xFF1A1A1A),
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                )
                              : Image.network(
                                  existingImageUrl!,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 220,
                                        color: const Color(0xFF1A1A1A),
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Нажмите для замены',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!has && !busy) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Фото помогает участникам быстрее найти событие',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.black),
        color: color,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
