import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../config/event_marker_catalog.dart';
import '../../models/event.dart';
import '../../widgets/event_marker_widget.dart';

class CreateEventDetailsScreen extends StatefulWidget {
  const CreateEventDetailsScreen({
    super.key,
    required this.position,
  });

  final LatLng position;

  @override
  State<CreateEventDetailsScreen> createState() => _CreateEventDetailsScreenState();
}

class _CreateEventDetailsScreenState extends State<CreateEventDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late Color _selectedColor;
  late IconData _selectedIcon;
  late int _userStatus;

  final _colors = EventMarkerCatalog.availableColors;
  late List<IconData> _icons;

  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    _userStatus = (Hive.box('authBox').get('status') as int?) ?? 1;
    _icons = EventMarkerCatalog.availableIconsForUserStatus(_userStatus);
    if (_icons.isEmpty) {
      _icons = EventMarkerCatalog.availableIconsForUserStatus(1);
    }
    _selectedColor = _colors.first;
    _selectedIcon = _icons.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEndsAt() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      initialDate: _endsAt ?? now,
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt ?? now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null) return;
    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _endsAt = dt;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final uuid = const Uuid();
    final event = Event(
      id: uuid.v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      lat: widget.position.latitude,
      lon: widget.position.longitude,
      createdAt: DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новое событие'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    EventMarkerWidget(
                      color: _selectedColor,
                      icon: _selectedIcon,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Маркер события',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Цвет', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((c) {
                final selected = c.value == _selectedColor.value;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = c),
                  borderRadius: BorderRadius.circular(999),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: c,
                    child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text('Иконка', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              _userStatus >= 2
                  ? 'Доступны иконки статуса 1 и 2'
                  : 'Доступны иконки статуса 1',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(i),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Введите название';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickEndsAt,
                      icon: const Icon(Icons.schedule),
                      label: Text(_endsAt == null ? 'Дата окончания (обязательно)' : 'Окончание: $_endsAt'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Создать'),
            ),
          ),
        ),
      ),
    );
  }
}

