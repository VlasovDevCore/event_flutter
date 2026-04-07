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
      // ignore (plugins may throw on some devices)
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
      // Fallback to local time converted to MSK approximation.
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
                          message: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
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
                                highlightColor: const Color.fromARGB(
                                  157,
                                  0,
                                  0,
                                  0,
                                ),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Фото события',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onPick,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          has ? 'Заменить' : 'Добавить',
                          style: TextStyle(color: scheme.primary),
                        ),
                ),
                if (has)
                  TextButton(
                    onPressed: busy ? null : onRemove,
                    child: Text(
                      'Убрать',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
            if (!has)
              Text(
                'Необязательно. Помогает людям быстрее понять, что за событие.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 200),
                  child: SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: Image.file(
                      File(path!),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: const Color(0xFF1A1A1A),
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
