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
    this.scrollController,
  });

  final List<Event> visibleEvents;
  final void Function(Event event) onEventTap;
  final ScrollController? scrollController;

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
  bool _loading = false;

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

    setState(() {
      _loading = true;
    });

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
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF1D2025);
    final divider = Colors.white.withOpacity(0.08);
    final subtitleColor = const Color(0xFFB5BBC7);
    final titleColor = Colors.white;

    final dateFormat = DateFormat('dd.MM.yyyy');

    return Material(
      color: bg,
      child: Container(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'События на экране: ${widget.visibleEvents.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: titleColor),
              ),
            ),
            Divider(height: 1, color: divider),
            Expanded(
              child: widget.visibleEvents.isEmpty
                  ? Center(
                      child: Text(
                        'На текущем экране событий нет',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: subtitleColor),
                      ),
                    )
                  : ListView.separated(
                      controller: widget.scrollController,
                      itemCount: widget.visibleEvents.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: divider),
                      itemBuilder: (context, index) {
                        final event = widget.visibleEvents[index];
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

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withOpacity(0.55),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  icon,
                                  size: 22,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            event.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дата: ${dateFormat.format(date)}',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              EventPreviewParticipantsRow(
                                participants: participants,
                                totalGoing: totalGoing,
                                previewLoading: previewLoading,
                              ),
                            ],
                          ),
                          onTap: () => widget.onEventTap(event),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

