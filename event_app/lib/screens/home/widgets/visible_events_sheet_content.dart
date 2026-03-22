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
    final itemCount = events.isEmpty ? 2 : events.length + 2;

    return Material(
      color: bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        controller: widget.scrollController,
        padding: widget.sheetPadding.copyWith(top: widget.sheetPadding.top + 2),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 10),
                  Text(
                    'События рядом',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            );
          }

          if (events.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'На карте событий нет',
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                      ),
                ),
              ),
            );
          }

          final lastIndex = events.length + 1;
          if (index == lastIndex) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                'Тусить будем?\n${events.length} поводов',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B3A3A),
                ),
                textAlign: TextAlign.left,
              ),
            );
          }

          final event = events[index - 1];
          final color = Color(event.markerColorValue);
          final icon = IconData(
            event.markerIconCodePoint,
            fontFamily: 'MaterialIcons',
          );

          final date = event.endsAt ?? event.createdAt;

          final participantsData = _participantsByEventId[event.id];
          final previewLoading = participantsData == null;
          final participants = participantsData?.participants ?? const [];
          final totalGoing = participantsData?.totalGoing ?? 0;

          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 4, 6),
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
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 20,
                            color: color,
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
    );
  }
}
