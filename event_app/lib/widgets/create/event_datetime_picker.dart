import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';

class EventDateTimePicker extends StatefulWidget {
  const EventDateTimePicker({
    super.key,
    required this.endsAt,
    required this.firstAllowedDay,
    required this.lastAllowedDay,
    required this.onDateTimeChanged,
  });

  final DateTime? endsAt;
  final DateTime firstAllowedDay;
  final DateTime lastAllowedDay;
  final Function(DateTime newDateTime) onDateTimeChanged;

  @override
  State<EventDateTimePicker> createState() => _EventDateTimePickerState();
}

class _EventDateTimePickerState extends State<EventDateTimePicker> {
  late DateTime _focusedDay;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    final endsAt =
        widget.endsAt ?? widget.firstAllowedDay.add(const Duration(days: 2));
    _focusedDay = endsAt;
    _selectedHour = endsAt.hour;
    _selectedMinute = endsAt.minute;
  }

  @override
  void didUpdateWidget(EventDateTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endsAt != oldWidget.endsAt && widget.endsAt != null) {
      _selectedHour = widget.endsAt!.hour;
      _selectedMinute = widget.endsAt!.minute;
      _focusedDay = widget.endsAt!;
    }
  }

  void _updateDateTime() {
    if (widget.endsAt == null) return;
    final newDateTime = DateTime(
      widget.endsAt!.year,
      widget.endsAt!.month,
      widget.endsAt!.day,
      _selectedHour,
      _selectedMinute,
    );
    widget.onDateTimeChanged(newDateTime);
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

  @override
  Widget build(BuildContext context) {
    const Color _inputFieldBg = Color(0xFF1F1F1F);
    const Color _inputFieldBorder = Color(0xFF222222);

    return Container(
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
                      _focusedDay.month == widget.firstAllowedDay.month &&
                          _focusedDay.year == widget.firstAllowedDay.year
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
                      _focusedDay.month == widget.lastAllowedDay.month &&
                          _focusedDay.year == widget.lastAllowedDay.year
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
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: TableCalendar<void>(
              locale: 'ru_RU',
              firstDay: widget.firstAllowedDay,
              lastDay: widget.lastAllowedDay,
              focusedDay: _focusedDay,
              availableGestures: AvailableGestures.horizontalSwipe,
              selectedDayPredicate: (day) =>
                  widget.endsAt != null && isSameDay(day, widget.endsAt),
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              headerVisible: false,
              daysOfWeekHeight: 24,
              rowHeight: 44,
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                  final newDateTime = DateTime(
                    selectedDay.year,
                    selectedDay.month,
                    selectedDay.day,
                    _selectedHour,
                    _selectedMinute,
                  );
                  widget.onDateTimeChanged(newDateTime);
                });
              },
              calendarBuilders: CalendarBuilders(
                dowBuilder: (context, day) {
                  const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
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
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Colors.white),
                outsideTextStyle: const TextStyle(color: Colors.white38),
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
                    GestureDetector(
                      onTap: () => _showTimePickerSheet(true),
                      child: Container(
                        width: 70,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedHour.toString().padLeft(2, '0'),
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
                    GestureDetector(
                      onTap: () => _showTimePickerSheet(false),
                      child: Container(
                        width: 70,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedMinute.toString().padLeft(2, '0'),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  widget.endsAt == null
                      ? '—'
                      : '${widget.endsAt!.day.toString().padLeft(2, '0')}.${widget.endsAt!.month.toString().padLeft(2, '0')}.${widget.endsAt!.year} ${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}',
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
    );
  }
}
