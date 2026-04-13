import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/event.dart';
import '../../../services/api_client.dart';
import '../../home/widgets/event_preview_participants_row.dart';
import '../../home/widgets/preview_participant.dart';

class ProfileActiveEventsSection extends StatefulWidget {
  const ProfileActiveEventsSection({
    super.key,
    required this.events,
    required this.onEventTap,
  });

  final List<Event> events;
  final void Function(Event event) onEventTap;

  @override
  State<ProfileActiveEventsSection> createState() =>
      _ProfileActiveEventsSectionState();
}

class _ParticipantsData {
  const _ParticipantsData({
    required this.participants,
    required this.totalGoing,
  });

  final List<PreviewParticipant> participants;
  final int totalGoing;
}

class _ProfileActiveEventsSectionState extends State<ProfileActiveEventsSection> {
  final Map<String, _ParticipantsData> _participantsByEventId = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadParticipants());
  }

  @override
  void didUpdateWidget(ProfileActiveEventsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.events.map((e) => e.id).toList();
    final newIds = widget.events.map((e) => e.id).toList();
    if (oldIds.join(',') != newIds.join(',')) {
      _participantsByEventId.clear();
      unawaited(_loadParticipants());
    }
  }

  Future<void> _loadParticipants() async {
    if (widget.events.isEmpty) return;

    final ids = widget.events.map((e) => e.id).toList(growable: false);
    try {
      final results = await Future.wait(
        ids.map((id) async {
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
        }),
      );

      if (!mounted) return;
      setState(() {
        for (final entry in results) {
          _participantsByEventId[entry.key] = entry.value;
        }
      });
    } catch (_) {
      // ignore
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
    final events = widget.events.take(3).toList(growable: false);
    if (events.isEmpty) return const SizedBox.shrink();

    const subtitleColor = Color(0xFFB5BBC7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(
            color: Color.fromARGB(144, 44, 44, 44),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 16),
          const Text(
            'Активные встречи',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 19,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final color = Color(event.markerColorValue);
            final gradientStart =
                Color.lerp(color, Colors.white, 0.22) ?? color;
            final gradientEnd =
                Color.lerp(color, Colors.black, 0.22) ?? color;
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
              padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
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
                    borderRadius: BorderRadius.circular(16),
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
                      subtitle: Row(
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
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

