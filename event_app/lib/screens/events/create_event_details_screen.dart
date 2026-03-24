import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';

import '../../config/event_marker_catalog.dart';
import '../../models/event.dart';
import '../../widgets/event_marker_widget.dart';

const Color _inputFieldBg = Color(0xFF1F1F1F);
const Color _inputFieldBorder = Color(0xFF222222);
const int _titleMaxLength = 60;
const int _descriptionMaxLength = 240;

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
  late DateTime _focusedDay;
  late DateTime _baseNow;
  bool _dateTimeEditedByUser = false;

  final _colors = EventMarkerCatalog.availableColors;
  late List<IconData> _icons;

  DateTime? _endsAt;
  int _selectedHour = 12;
  int _selectedMinute = 0;

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
    _focusedDay = _endsAt!;
    _selectedHour = _endsAt!.hour;
    _selectedMinute = _endsAt!.minute;
    _syncMoscowNow();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateDateTime() {
    if (_endsAt == null) return;
    setState(() {
      _dateTimeEditedByUser = true;
      _endsAt = DateTime(
        _endsAt!.year,
        _endsAt!.month,
        _endsAt!.day,
        _selectedHour,
        _selectedMinute,
      );
    });
  }

  Future<void> _showTimePickerSheet(bool isHour) async {
    final int initialValue = isHour ? _selectedHour : _selectedMinute;
    final int maxValue = isHour ? 23 : 59;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isHour ? 'Выберите час' : 'Выберите минуты',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: const Color(0xFF161616),
                  itemExtent: 48,
                  scrollController: FixedExtentScrollController(
                    initialItem: initialValue,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() {
                      if (isHour) {
                        _selectedHour = index;
                      } else {
                        _selectedMinute = index;
                      }
                      _updateDateTime();
                    });
                  },
                  children: List.generate(maxValue + 1, (index) {
                    return Center(
                      child: Text(
                        index.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
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

  String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  String _monthTitle(DateTime day) {
    const months = <String>[
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    final month = months[day.month - 1];
    final monthUpper = '${month[0].toUpperCase()}${month.substring(1)}';
    return '$monthUpper ${day.year}';
  }

  DateTime get _firstAllowedDay =>
      DateTime(_baseNow.year, _baseNow.month, _baseNow.day);

  DateTime get _lastAllowedDay {
    final max = _baseNow.add(const Duration(days: 7));
    return DateTime(max.year, max.month, max.day);
  }

  DateTime _clampToAllowedRange(DateTime value) {
    final dayOnly = DateTime(value.year, value.month, value.day);
    if (dayOnly.isBefore(_firstAllowedDay)) {
      return DateTime(
        _firstAllowedDay.year,
        _firstAllowedDay.month,
        _firstAllowedDay.day,
        value.hour,
        value.minute,
      );
    }
    if (dayOnly.isAfter(_lastAllowedDay)) {
      return DateTime(
        _lastAllowedDay.year,
        _lastAllowedDay.month,
        _lastAllowedDay.day,
        value.hour,
        value.minute,
      );
    }
    return value;
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
        final fallbackDefault = _baseNow.add(const Duration(days: 2));
        final resolved = _dateTimeEditedByUser
            ? _clampToAllowedRange(_endsAt ?? fallbackDefault)
            : fallbackDefault;
        _endsAt = resolved;
        _focusedDay = DateTime(resolved.year, resolved.month, 1);
        _selectedHour = _endsAt!.hour;
        _selectedMinute = _endsAt!.minute;
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
                Card(
                  elevation: 0,
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        EventMarkerWidget(
                          color: _selectedColor,
                          icon: _selectedIcon,
                          size: 45,
                          iconSize: 23,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Маркер события',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                EventMarkerCatalog.categoryLabelForCodePoint(
                                      _selectedIcon.codePoint,
                                    ) ??
                                    'Без категории',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Цвет',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    height: 1,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 6.0;
                    const minColumns = 6;
                    const minTileSize = 44.0;
                    final calculatedColumns =
                        ((constraints.maxWidth + spacing) /
                                (minTileSize + spacing))
                            .floor();
                    final crossAxisCount = calculatedColumns < minColumns
                        ? minColumns
                        : calculatedColumns;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _colors.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final c = _colors[index];
                        final selected = c.value == _selectedColor.value;
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = c),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: selected
                                ? const Center(
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 15),
                Text(
                  'Иконка',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    height: 1,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 6.0;
                    const minColumns = 6;
                    const minTileSize = 44.0;
                    final calculatedColumns =
                        ((constraints.maxWidth + spacing) /
                                (minTileSize + spacing))
                            .floor();
                    final crossAxisCount = calculatedColumns < minColumns
                        ? minColumns
                        : calculatedColumns;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _icons.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final i = _icons[index];
                        final selected = i.codePoint == _selectedIcon.codePoint;
                        return InkWell(
                          onTap: () => setState(() => _selectedIcon = i),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
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
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Название',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _titleController,
                            builder: (context, value, _) {
                              return Text(
                                '${value.text.characters.length}/$_titleMaxLength',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        maxLength: _titleMaxLength,
                        buildCounter:
                            (
                              context, {
                              required int currentLength,
                              required bool isFocused,
                              required int? maxLength,
                            }) {
                              return const SizedBox.shrink();
                            },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Вечерний кофе и разговоры',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: _inputFieldBg,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: _inputFieldBorder,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: _inputFieldBorder,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Введите название';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Описание',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _descriptionController,
                            builder: (context, value, _) {
                              return Text(
                                '${value.text.characters.length}/$_descriptionMaxLength',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLength: _descriptionMaxLength,
                        buildCounter:
                            (
                              context, {
                              required int currentLength,
                              required bool isFocused,
                              required int? maxLength,
                            }) {
                              return const SizedBox.shrink();
                            },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Кого ждёте, что планируете и что взять с собой',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: _inputFieldBg,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: _inputFieldBorder,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: _inputFieldBorder,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        maxLines: 3,
                      ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _inputFieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _inputFieldBorder),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFF232323),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        _focusedDay.month ==
                                                _firstAllowedDay.month &&
                                            _focusedDay.year ==
                                                _firstAllowedDay.year
                                        ? null
                                        : () {
                                            setState(() {
                                              _focusedDay = DateTime(
                                                _focusedDay.year,
                                                _focusedDay.month - 1,
                                                1,
                                              );
                                            });
                                          },
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        _monthTitle(_focusedDay),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFF232323),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        _focusedDay.month ==
                                                _lastAllowedDay.month &&
                                            _focusedDay.year ==
                                                _lastAllowedDay.year
                                        ? null
                                        : () {
                                            setState(() {
                                              _focusedDay = DateTime(
                                                _focusedDay.year,
                                                _focusedDay.month + 1,
                                                1,
                                              );
                                            });
                                          },
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                right: 4,
                                bottom: 10,
                              ),
                              child: TableCalendar<void>(
                                locale: 'ru_RU',
                                firstDay: _firstAllowedDay,
                                lastDay: _lastAllowedDay,
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) =>
                                    _endsAt != null && isSameDay(day, _endsAt),
                                availableCalendarFormats: const {
                                  CalendarFormat.month: 'Month',
                                },
                                headerVisible: false,
                                daysOfWeekHeight: 24,
                                rowHeight: 44,
                                onPageChanged: (focusedDay) {
                                  setState(() => _focusedDay = focusedDay);
                                },
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _dateTimeEditedByUser = true;
                                    _focusedDay = focusedDay;
                                    _endsAt = DateTime(
                                      selectedDay.year,
                                      selectedDay.month,
                                      selectedDay.day,
                                      _selectedHour,
                                      _selectedMinute,
                                    );
                                  });
                                },
                                calendarBuilders: CalendarBuilders(
                                  dowBuilder: (context, day) {
                                    const labels = [
                                      'Пн',
                                      'Вт',
                                      'Ср',
                                      'Чт',
                                      'Пт',
                                      'Сб',
                                      'Вс',
                                    ];
                                    return Center(
                                      child: Text(
                                        labels[day.weekday - 1],
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                calendarStyle: CalendarStyle(
                                  isTodayHighlighted: true,
                                  defaultTextStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  weekendTextStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  outsideTextStyle: const TextStyle(
                                    color: Colors.white38,
                                  ),
                                  todayTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  selectedTextStyle: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  selectedDecoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  todayDecoration: BoxDecoration(
                                    color: const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  defaultDecoration: BoxDecoration(
                                    color: const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  weekendDecoration: BoxDecoration(
                                    color: const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  outsideDecoration: BoxDecoration(
                                    color: const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  cellMargin: const EdgeInsets.all(3),
                                ),
                                daysOfWeekStyle: const DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  weekendStyle: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const Divider(color: Color(0xFF333333), height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Время:',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Кастомное поле для часов
                                      GestureDetector(
                                        onTap: () => _showTimePickerSheet(true),
                                        child: Container(
                                          width: 70,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2C2C2C),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  _selectedHour
                                                      .toString()
                                                      .padLeft(2, '0'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.expand_more,
                                                  color: Colors.white70,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        ':',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Кастомное поле для минут
                                      GestureDetector(
                                        onTap: () =>
                                            _showTimePickerSheet(false),
                                        child: Container(
                                          width: 70,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2C2C2C),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  _selectedMinute
                                                      .toString()
                                                      .padLeft(2, '0'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.expand_more,
                                                  color: Colors.white70,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _endsAt == null
                                        ? '—'
                                        : '${_endsAt!.day.toString().padLeft(2, '0')}.${_endsAt!.month.toString().padLeft(2, '0')}.${_endsAt!.year} ${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Кнопка "Создать" внизу контента
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Создать',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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
