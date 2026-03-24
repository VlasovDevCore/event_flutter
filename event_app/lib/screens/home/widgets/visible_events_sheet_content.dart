import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/event.dart';
import '../../../services/api_client.dart';

import 'event_preview_participants_row.dart';
import 'preview_participant.dart';

class VisibleEventsSheetContent extends StatefulWidget {
  const VisibleEventsSheetContent({
    super.key,
    required this.visibleEvents,
    required this.onEventTap,
    required this.scrollController,
    required this.sheetPadding,
  });

  final List<Event> visibleEvents;
  final void Function(Event event) onEventTap;
  final ScrollController scrollController;
  final EdgeInsets sheetPadding;

  @override
  State<VisibleEventsSheetContent> createState() => _VisibleEventsSheetContentState();
}

class _ParticipantsData {
  const _ParticipantsData({
    required this.participants,
    required this.totalGoing,
  });

  final List<PreviewParticipant> participants;
  final int totalGoing;
}

class _VisibleEventsSheetContentState extends State<VisibleEventsSheetContent> {
  static const int _maxToLoad = 20;

  final Map<String, _ParticipantsData> _participantsByEventId = {};

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  @override
  void didUpdateWidget(VisibleEventsSheetContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIds = oldWidget.visibleEvents.map((e) => e.id).toList();
    final newIds = widget.visibleEvents.map((e) => e.id).toList();
    if (oldIds.join(',') != newIds.join(',')) {
      _participantsByEventId.clear();
      _loadParticipants();
    }
  }

  Future<void> _loadParticipants() async {
    if (widget.visibleEvents.isEmpty) return;

    final ids = widget.visibleEvents
        .take(_maxToLoad)
        .map((e) => e.id)
        .toList(growable: false);

    try {
      final results = await Future.wait(ids.map((id) async {
        final data = await ApiClient.instance.get('/events/$id');
        final event = Event.fromApiMap(data);

        final participants = event.goingUserProfiles.isNotEmpty
            ? event.goingUserProfiles
                .map(
                  (p) => PreviewParticipant(
                    label: p.displayName ?? p.username ?? p.email ?? 'U',
                    avatarUrl: p.avatarUrl,
                    status: p.status,
                  ),
                )
                .toList()
            : event.goingUsers
                .map(
                  (email) => PreviewParticipant(
                    label: email,
                    avatarUrl: null,
                    status: 1,
                  ),
                )
                .toList();

        return MapEntry(
          id,
          _ParticipantsData(
            participants: participants,
            totalGoing: event.goingUsers.length,
          ),
        );
      }));

      if (!mounted) return;
      setState(() {
        for (final entry in results) {
          _participantsByEventId[entry.key] = entry.value;
        }
      });
    } catch (_) {
      // Участники могут остаться пустыми; карточки покажут загрузку превью.
    }
  }

  String _formatEventDateTimeLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now().toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(local.year, local.month, local.day);
    final tomorrow = today.add(const Duration(days: 1));

    String dayPart;
    if (dateDay == today) {
      dayPart = 'Сегодня';
    } else if (dateDay == tomorrow) {
      dayPart = 'Завтра';
    } else {
      const weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      dayPart = weekdays[local.weekday % 7];
    }

    final time = DateFormat('HH:mm').format(local);
    return '$dayPart, $time';
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF161616);
    final subtitleColor = const Color(0xFFB5BBC7);
    final events = widget.visibleEvents;
    final listItemCount = events.isEmpty ? 1 : events.length + 1;

    return Material(
      color: bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.sheetPadding.left + 16,
              widget.sheetPadding.top + 6,
              widget.sheetPadding.right + 16,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'События рядом',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    widget.sheetPadding.left,
                    0,
                    widget.sheetPadding.right,
                    widget.sheetPadding.bottom + 88,
                  ),
                  itemCount: listItemCount,
                  itemBuilder: (context, index) {
                    if (events.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Center(
                          child: Text(
                            'На карте событий нет',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: subtitleColor,
                                ),
                          ),
                        ),
                      );
                    }

                    final lastIndex = events.length;
                    if (index == lastIndex) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Center(
                          child: Text(
                            'Тусить будем?\n${events.length} поводов',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B3A3A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final event = events[index];
          final color = Color(event.markerColorValue);
          final gradientStart = Color.lerp(color, Colors.white, 0.22) ?? color;
          final gradientEnd = Color.lerp(color, Colors.black, 0.22) ?? color;
          final icon = IconData(
            event.markerIconCodePoint,
            fontFamily: 'MaterialIcons',
          );

          final date = event.endsAt ?? event.createdAt;

          final participantsData = _participantsByEventId[event.id];
          final previewLoading = participantsData == null;
          final participants = participantsData?.participants ?? const [];
          final totalGoing = participantsData?.totalGoing ?? 0;

                    final topCardInset = index == 0 ? 14.0 : 6.0;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(16, topCardInset, 4, 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            splashFactory: NoSplash.splashFactory,
                            highlightColor: Colors.transparent,
                            onTap: () => widget.onEventTap(event),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 5,
                              ),
                              leading: SizedBox(
                                width: 50,
                                height: 50,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [gradientStart, gradientEnd],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                event.title,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                              ),
                              subtitle: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: subtitleColor.withValues(alpha: 0.9),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _formatEventDateTimeLabel(date),
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              color: Color(0xFFAAABB0),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '•',
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 16,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: EventPreviewParticipantsRow(
                                            participants: participants,
                                            totalGoing: totalGoing,
                                            previewLoading: previewLoading,
                                            color: const Color(0xFF8FF5FF),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 15,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF161616), 
                            Color(0xE6161616),
                            Color(0x00161616), 
                          ],
                        ),
                      ),
                    ),
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
