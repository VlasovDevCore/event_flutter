import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/event_marker_catalog.dart';
import '../../../models/event.dart';
import '../../widgets/create/event_color_picker.dart';
import '../../widgets/create/event_create_button.dart';
import '../../widgets/create/event_datetime_picker.dart';
import '../../widgets/create/event_description_field.dart';
import '../../widgets/create/event_icon_picker.dart';
import '../../widgets/create/event_marker_preview_card.dart';
import '../../widgets/create/event_title_field.dart';

class CreateEventDetailsScreen extends StatefulWidget {
  const CreateEventDetailsScreen({super.key, required this.position});

  final LatLng position;

  @override
  State<CreateEventDetailsScreen> createState() =>
      _CreateEventDetailsScreenState();
}

class _CreateEventDetailsScreenState extends State<CreateEventDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late Color _selectedColor;
  late IconData _selectedIcon;
  late int _userStatus;
  late DateTime _baseNow;
  bool _dateTimeEditedByUser = false;
  String? _localImagePath;
  bool _photoBusy = false;

  final _colors = EventMarkerCatalog.availableColors;
  late List<IconData> _icons;

  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    _userStatus = (Hive.box('authBox').get('status') as int?) ?? 1;
    _icons = EventMarkerCatalog.availableIconsForUserStatus(_userStatus);
    if (_icons.isEmpty) {
      _icons = EventMarkerCatalog.availableIconsForUserStatus(1);
    }
    _selectedColor = _colors.first;
    _selectedIcon = _icons.first;
    _baseNow = now;
    _endsAt = now.add(const Duration(days: 2));
    _syncMoscowNow();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDateTimeChanged(DateTime newDateTime) {
    setState(() {
      _dateTimeEditedByUser = true;
      _endsAt = newDateTime;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final uuid = const Uuid();
    final event = Event(
      id: uuid.v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      localImagePath: _localImagePath,
      lat: widget.position.latitude,
      lon: widget.position.longitude,
      createdAt: _baseNow,
      markerColorValue: _selectedColor.toARGB32(),
      markerIconCodePoint: _selectedIcon.codePoint,
      rsvpStatus: 0,
      goingUsers: const [],
      notGoingUsers: const [],
      goingUserProfiles: const [],
      notGoingUserProfiles: const [],
      endsAt: _endsAt,
    );

    Navigator.of(context).pop(event);
  }

  Future<void> _pickEventPhoto() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2000,
      );
      if (x == null) return;
      if (!mounted) return;
      setState(() => _localImagePath = x.path);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _removeEventPhoto() {
    setState(() => _localImagePath = null);
  }

  DateTime get _firstAllowedDay =>
      DateTime(_baseNow.year, _baseNow.month, _baseNow.day);

  DateTime get _lastAllowedDay {
    final max = _baseNow.add(const Duration(days: 7));
    return DateTime(max.year, max.month, max.day);
  }

  Future<void> _syncMoscowNow() async {
    try {
      final uri = Uri.parse(
        'https://worldtimeapi.org/api/timezone/Europe/Moscow',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return;
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final datetimeRaw = map['datetime']?.toString();
      if (datetimeRaw == null || datetimeRaw.isEmpty) return;
      final internetNow = DateTime.parse(datetimeRaw);
      if (!mounted) return;
      setState(() {
        _baseNow = internetNow;
        if (!_dateTimeEditedByUser) {
          _endsAt = _baseNow.add(const Duration(days: 2));
        }
      });
    } catch (_) {
      // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.35,
                  colors: [
                    _selectedColor.withValues(alpha: 0.55),
                    _selectedColor.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Tooltip(
                          message: MaterialLocalizations.of(context).backButtonTooltip,
                          child: Container(
                            width: 37,
                            height: 37,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(157, 0, 0, 0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.of(context).maybePop(),
                                splashColor: const Color.fromARGB(157, 0, 0, 0),
                                highlightColor: const Color.fromARGB(157, 0, 0, 0),
                                child: const Center(
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Новое событие',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                EventMarkerPreviewCard(
                  color: _selectedColor,
                  icon: _selectedIcon,
                ),
                const SizedBox(height: 12),
                
                // ОБНОВЛЕННЫЙ ВИДЖЕТ ФОТО (в стиле DetailEditSheet)
                _EventPhotoPicker(
                  path: _localImagePath,
                  onPick: _photoBusy ? null : _pickEventPhoto,
                  onRemove: _removeEventPhoto,
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
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Дата и время',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      EventDateTimePicker(
                        endsAt: _endsAt,
                        firstAllowedDay: _firstAllowedDay,
                        lastAllowedDay: _lastAllowedDay,
                        onDateTimeChanged: _onDateTimeChanged,
                      ),
                      const SizedBox(height: 24),
                      EventCreateButton(onPressed: _submit),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ОБНОВЛЕННЫЙ ВИДЖЕТ ФОТО (в стиле DetailEditSheet)
class _EventPhotoPicker extends StatelessWidget {
  const _EventPhotoPicker({
    required this.path,
    required this.onPick,
    required this.onRemove,
    required this.busy,
  });

  final String? path;
  final VoidCallback? onPick;
  final VoidCallback onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final has = path != null && path!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: has
              ? const Color(0xFFFFFFFF).withValues(alpha: 0.3)
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
                          Image.file(
                            File(path!),
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 220,
                              color: const Color(0xFF1A1A1A),
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.3),
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
                                      color: Colors.white.withValues(alpha: 0.7),
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