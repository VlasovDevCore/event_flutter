import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/event.dart';
import '../widgets/event_marker_widget.dart';

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

  final _colors = <Color>[
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  final _icons = <IconData>[
    Icons.flutter_dash,
    Icons.music_note,
    Icons.groups,
    Icons.storefront,
    Icons.sports_soccer,
    Icons.local_cafe,
    Icons.movie,
    Icons.celebration,
  ];

  static const int _maxDaysAhead = 7;

  late DateTime _endsAt;
  late TimeOfDay _endsTime;

  @override
  void initState() {
    super.initState();
    _selectedColor = _colors.first;
    _selectedIcon = _icons.first;
    final now = DateTime.now();
    _endsTime = const TimeOfDay(hour: 23, minute: 59);
    _endsAt = now.add(const Duration(days: _maxDaysAhead));
    _endsAt = DateTime(_endsAt.year, _endsAt.month, _endsAt.day, _endsTime.hour, _endsTime.minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEndsAt() async {
    final now = DateTime.now();
    final max = now.add(const Duration(days: _maxDaysAhead));
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: now,
      lastDate: max,
      helpText: 'До какой даты актуально (макс. неделя вперёд)',
    );
    if (picked != null && mounted) {
      setState(() {
        _endsAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _endsTime.hour,
          _endsTime.minute,
        );
      });
    }
  }

  Future<void> _pickEndsTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endsTime,
      helpText: 'До какого времени актуально',
    );
    if (picked != null && mounted) {
      setState(() {
        _endsTime = picked;
        _endsAt = DateTime(
          _endsAt.year,
          _endsAt.month,
          _endsAt.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final event = Event(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      lat: widget.position.latitude,
      lon: widget.position.longitude,
      createdAt: DateTime.now(),
      markerColorValue: _selectedColor.value,
      markerIconCodePoint: _selectedIcon.codePoint,
      rsvpStatus: 0,
      goingUsers: const [],
      notGoingUsers: const [],
      endsAt: _endsAt,
    );

    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали события'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Предпросмотр маркера',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Center(
              child: EventMarkerWidget(
                color: _selectedColor,
                icon: _selectedIcon,
                size: 44,
                iconSize: 22,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Иконка',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _icons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final icon = _icons[index];
                  final selected = icon == _selectedIcon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Цвет',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((c) {
                final selected = c.value == _selectedColor.value;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = c),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Актуально до (дата)'),
              subtitle: Text(
                '${_endsAt.day.toString().padLeft(2, '0')}.${_endsAt.month.toString().padLeft(2, '0')}.${_endsAt.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickEndsAt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Актуально до (время)'),
              subtitle: Text(
                '${_endsTime.hour.toString().padLeft(2, '0')}:${_endsTime.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _pickEndsTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите заголовок';
                      }
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
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Создать'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

