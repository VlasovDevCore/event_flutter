import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../services/api_client.dart';
import '../chat/event_chat_screen.dart';
import '../events/event_details_screen.dart';
import '../home/widgets/event_preview_participants_row.dart';
import '../home/widgets/preview_participant.dart';

/// Комнаты: вкладка «Участвую» (RSVP) и «Создал» (мои события).
/// Тап по строке — чат; иконка «расширить» — подробности.
class MyRoomsScreen extends StatefulWidget {
  const MyRoomsScreen({super.key});

  @override
  State<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

class _ParticipantsData {
  const _ParticipantsData({
    required this.participants,
    required this.totalGoing,
  });

  final List<PreviewParticipant> participants;
  final int totalGoing;
}

class _MyRoomsScreenState extends State<MyRoomsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Event> _roomsParticipating = [];
  List<Event> _roomsCreated = [];
  final Map<String, _ParticipantsData> _participantsByEventId = {};

  bool _loadingParticipating = true;
  bool _loadingCreated = true;
  String? _errorParticipating;
  String? _errorCreated;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadParticipating();
    _loadCreated();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadParticipating(),
      _loadCreated(),
    ]);
  }

  Future<void> _loadParticipating() async {
    setState(() {
      _loadingParticipating = true;
      _errorParticipating = null;
    });
    try {
      final list =
          await ApiClient.instance.getList('/events/my/rooms', withAuth: true);
      final events = list.map((raw) {
        final map = raw as Map<String, dynamic>;
        return Event.fromApiMap(map);
      }).toList();

      if (!mounted) return;
      setState(() {
        _roomsParticipating = events;
        _loadingParticipating = false;
      });
      await _loadParticipantsForEvents(events);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorParticipating =
            e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _roomsParticipating = [];
        _loadingParticipating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorParticipating = e.toString();
        _roomsParticipating = [];
        _loadingParticipating = false;
      });
    }
  }

  Future<void> _loadCreated() async {
    setState(() {
      _loadingCreated = true;
      _errorCreated = null;
    });
    try {
      final list =
          await ApiClient.instance.getList('/events/my/created', withAuth: true);
      final events = list.map((raw) {
        final map = raw as Map<String, dynamic>;
        return Event.fromApiMap(map);
      }).toList();

      if (!mounted) return;
      setState(() {
        _roomsCreated = events;
        _loadingCreated = false;
      });
      await _loadParticipantsForEvents(events);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCreated =
            e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _roomsCreated = [];
        _loadingCreated = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCreated = e.toString();
        _roomsCreated = [];
        _loadingCreated = false;
      });
    }
  }

  Future<void> _loadParticipantsForEvents(List<Event> events) async {
    if (events.isEmpty) return;

    try {
      final results = await Future.wait(events.map((event) async {
        final data = await ApiClient.instance.get('/events/${event.id}');
        final loaded = Event.fromApiMap(data);

        final participants = loaded.goingUserProfiles.isNotEmpty
            ? loaded.goingUserProfiles
                .map(
                  (p) => PreviewParticipant(
                    label: p.displayName ?? p.username ?? p.email ?? 'U',
                    avatarUrl: p.avatarUrl,
                    status: p.status,
                  ),
                )
                .toList()
            : loaded.goingUsers
                .map(
                  (email) => PreviewParticipant(
                    label: email,
                    avatarUrl: null,
                    status: 1,
                  ),
                )
                .toList();

        return MapEntry(
          event.id,
          _ParticipantsData(
            participants: participants,
            totalGoing: loaded.goingUsers.length,
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
      // Не блокируем экран, если не удалось подгрузить участников.
    }
  }

  Widget _buildEventListTile(Event event, DateFormat dateFormat, Color subtitleColor) {
    final color = Color(event.markerColorValue);
    final icon = IconData(
      event.markerIconCodePoint,
      fontFamily: 'MaterialIcons',
    );
    final isEnded =
        event.endsAt != null && event.endsAt!.isBefore(DateTime.now());
    final date = event.endsAt ?? event.createdAt;

    final participantsData = _participantsByEventId[event.id];
    final previewLoading = participantsData == null;
    final participants =
        participantsData?.participants ?? const <PreviewParticipant>[];
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
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
          if (isEnded) ...[
            const SizedBox(height: 6),
            Text(
              'Событие завершено',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.open_in_full_rounded),
        tooltip: 'Подробности события',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventDetailsScreen(event: event),
            ),
          );
        },
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventChatScreen(event: event),
          ),
        );
      },
    );
  }

  Widget _buildTabBody({
    required bool loading,
    required String? error,
    required List<Event> events,
    required String emptyMessage,
    required DateFormat dateFormat,
    required Color subtitleColor,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (events.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _buildEventListTile(events[index], dateFormat, subtitleColor);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final subtitleColor = const Color(0xFFB5BBC7);
    final busy = _loadingParticipating || _loadingCreated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('События'),
        actions: [
          IconButton(
            onPressed: busy ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Участвую'),
            Tab(text: 'Создал'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabBody(
            loading: _loadingParticipating,
            error: _errorParticipating,
            events: _roomsParticipating,
            emptyMessage:
                'Вы пока не участвуете ни в одном событии.\nОтметьте «Я приду» в деталях события.',
            dateFormat: dateFormat,
            subtitleColor: subtitleColor,
          ),
          _buildTabBody(
            loading: _loadingCreated,
            error: _errorCreated,
            events: _roomsCreated,
            emptyMessage:
                'Вы ещё не создавали событий.\nСоздайте событие на карте.',
            dateFormat: dateFormat,
            subtitleColor: subtitleColor,
          ),
        ],
      ),
    );
  }
}
