import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

import '../../models/event.dart';
import '../../services/api_client.dart';
import '../chat/event_chat_screen.dart';
import '../events/event_details_screen.dart';
import '../events/create_event_details_screen.dart';
import '../events/create_event_location_screen.dart';
import '../home/widgets/event_preview_participants_row.dart';
import '../home/widgets/preview_participant.dart';

import '../../app_route_observer.dart';
import '../../utils/icon_helper.dart';

/// Комнаты: вкладка «Участвую» (RSVP) и «Создал» (мои события).
/// Тап по строке — детальная информация; иконка чата — чат.
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
    with RouteAware, SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Event> _roomsParticipating = [];
  List<Event> _roomsCreated = [];
  final Map<String, _ParticipantsData> _participantsByEventId = {};
  final Map<String, _RoomMeta> _metaByEventId = {};

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  /// Сняли чат/детали — перезапрашиваем списки, иначе «Участвую» остаётся устаревшим.
  @override
  void didPopNext() {
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadParticipating(), _loadCreated()]);
  }

  int _unreadCountForEvent(String eventId) =>
      _metaByEventId[eventId]?.unreadCount ?? 0;

  bool _isMutedNowForEvent(String eventId) {
    final until = _metaByEventId[eventId]?.mutedUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  Future<void> _loadRoomsMetaFor(List<Event> events) async {
    final ids =
        events.map((e) => e.id).where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;
    try {
      final data = await ApiClient.instance.post(
        '/events/rooms-meta',
        withAuth: true,
        body: {'eventIds': ids},
      );
      final byEvent = data['byEvent'];
      if (byEvent is! Map) return;

      final next = <String, _RoomMeta>{..._metaByEventId};
      for (final entry in byEvent.entries) {
        final eventId = entry.key.toString();
        final v = entry.value;
        if (v is! Map) continue;
        final unreadRaw = v['unread_count'];
        final mutedRaw = v['muted_until'];
        final unread =
            unreadRaw is int ? unreadRaw : int.tryParse('$unreadRaw') ?? 0;
        DateTime? mutedUntil;
        if (mutedRaw is String && mutedRaw.trim().isNotEmpty) {
          mutedUntil = DateTime.tryParse(mutedRaw)?.toLocal();
        }
        next[eventId] = _RoomMeta(unreadCount: unread, mutedUntil: mutedUntil);
      }

      if (!mounted) return;
      setState(() {
        _metaByEventId
          ..clear()
          ..addAll(next);
      });
    } catch (_) {}
  }

  Future<void> _loadParticipating() async {
    setState(() {
      _loadingParticipating = true;
      _errorParticipating = null;
    });
    try {
      final list = await ApiClient.instance.getList(
        '/events/my/rooms',
        withAuth: true,
      );
      final events = list.map((raw) {
        final map = raw as Map<String, dynamic>;
        return Event.fromApiMap(map);
      }).toList();

      if (!mounted) return;
      setState(() {
        _roomsParticipating = events;
        _loadingParticipating = false;
      });
      await _loadRoomsMetaFor(events);
      await _loadParticipantsForEvents(events);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorParticipating = e.statusCode == 401
            ? 'Войдите в аккаунт'
            : e.message;
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
      final list = await ApiClient.instance.getList(
        '/events/my/created',
        withAuth: true,
      );
      final events = list.map((raw) {
        final map = raw as Map<String, dynamic>;
        return Event.fromApiMap(map);
      }).toList();

      if (!mounted) return;
      setState(() {
        _roomsCreated = events;
        _loadingCreated = false;
      });
      await _loadRoomsMetaFor(events);
      await _loadParticipantsForEvents(events);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCreated = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
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
      final results = await Future.wait(
        events.map((event) async {
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
        }),
      );

      if (!mounted) return;
      setState(() {
        for (final entry in results) {
          _participantsByEventId[entry.key] = entry.value;
        }
        // Обновляем события, чтобы перерисовать иконки
        _roomsParticipating = List.from(_roomsParticipating);
        _roomsCreated = List.from(_roomsCreated);
      });
    } catch (_) {
      // Не блокируем экран, если не удалось подгрузить участников.
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

  Widget _buildEventListTile(Event event) {
    final color = Color(event.markerColorValue);
    final gradientStart = Color.lerp(color, Colors.white, 0.22) ?? color;
    final gradientEnd = Color.lerp(color, Colors.black, 0.22) ?? color;

    // Получаем иконку напрямую, без кеширования
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
    final unread = _unreadCountForEvent(event.id);
    final isMuted = _isMutedNowForEvent(event.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EventDetailsScreen(event: event),
                ),
              );
            },
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
                    child: Icon(icon, size: 20, color: Colors.white),
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
                  if (isMuted) ...[
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 14,
                      color: const Color(0xFFB5BBC7).withOpacity(0.9),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isEnded) ...[
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: const Color(0xFFB5BBC7).withOpacity(0.9),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        isEnded ? 'Завершено' : _formatEventDateTimeLabel(date),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isEnded
                              ? Colors.grey[600]
                              : const Color(0xFFAAABB0),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  EventPreviewParticipantsRow(
                    participants: participants,
                    totalGoing: totalGoing,
                    previewLoading: previewLoading,
                    color: const Color(0xFF8FF5FF),
                  ),
                ],
              ),
              trailing: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF161616),
                        size: 18,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EventChatScreen(event: event),
                          ),
                        );
                      },
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Badge(
                        label: Text(unread > 99 ? '99+' : '$unread'),
                        child: const SizedBox(width: 1, height: 1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 0.55,
            colors: [
              const Color.fromARGB(197, 29, 29, 29),
              const Color(0xFF161616),
            ],
            stops: const [0.1, 4.9],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'События',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
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
            highlightColor: const Color.fromARGB(157, 0, 0, 0),
            child: const Center(
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    final busy = _loadingParticipating || _loadingCreated;

    return Container(
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
          onTap: busy ? null : _refreshAll,
          splashColor: const Color.fromARGB(157, 0, 0, 0),
          highlightColor: const Color.fromARGB(157, 0, 0, 0),
          child: const Center(
            child: Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          dividerColor: Colors.transparent,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          tabs: const [
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event, size: 16),
                    SizedBox(width: 6),
                    Text('Участвую'),
                  ],
                ),
              ),
            ),
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.create, size: 16),
                    SizedBox(width: 6),
                    Text('Создал'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateEventButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5F57), Color(0xFFFEBC2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          minimumSize: const Size(200, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: () async {
          // Для создания события используем координаты по умолчанию
          final initialCenter = const LatLng(55.751244, 37.618423);

          final navigator = Navigator.of(context);
          final selected = await navigator.push<LatLng>(
            MaterialPageRoute(
              builder: (_) =>
                  CreateEventLocationScreen(initialCenter: initialCenter),
            ),
          );
          if (!mounted) return;
          if (selected == null) return;

          final created = await navigator.push<Event>(
            MaterialPageRoute(
              builder: (_) => CreateEventDetailsScreen(position: selected),
            ),
          );
          if (!mounted) return;
          if (created == null) return;

          await _addEvent(created);
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Создать событие',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEvent(Event event) async {
    if (event.endsAt == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите дату окончания события')),
      );
      return;
    }

    final client = ApiClient.instance;
    try {
      final created = await client.post(
        '/events',
        withAuth: true,
        body: {
          'title': event.title,
          'description': event.description,
          'lat': event.lat,
          'lon': event.lon,
          'markerColorValue': event.markerColorValue,
          'markerIconCode': event.markerIconCodePoint,
          'endsAt': event.endsAt!.toIso8601String(),
        },
      );

      final me = _currentUserEmail();
      Event newEvent = Event(
        id: created['id'] as String,
        title: created['title'] as String,
        description: created['description'] as String? ?? '',
        imageUrl: created['image_url']?.toString(),
        lat: (created['lat'] as num).toDouble(),
        lon: (created['lon'] as num).toDouble(),
        createdAt: DateTime.parse(created['created_at'] as String),
        markerColorValue: int.parse(created['marker_color_value'].toString()),
        markerIconCodePoint: int.parse(created['marker_icon_code'].toString()),
        rsvpStatus: 1,
        goingUsers: me != null ? [me] : const [],
        notGoingUsers: const [],
        goingUserProfiles: const [],
        notGoingUserProfiles: const [],
        endsAt: created['ends_at'] != null
            ? DateTime.parse(created['ends_at'] as String)
            : null,
        creatorId: created['created_by_user_id']?.toString(),
        creatorEmail: created['created_by_email']?.toString(),
        creatorName:
            (created['created_by_display_name'] ??
                    created['created_by_username'])
                ?.toString(),
      );

      setState(() {
        _roomsCreated = [..._roomsCreated, newEvent];
      });

      final localPath = event.localImagePath;
      if (localPath != null && localPath.trim().isNotEmpty) {
        try {
          final bytes = await File(localPath).readAsBytes();
          final uploaded = await client.uploadImage(
            '/events/${newEvent.id}/image',
            bytes: bytes,
            filename: 'event-${newEvent.id}.jpg',
            fieldName: 'image',
            withAuth: true,
          );
          final imageUrl =
              (uploaded['image_url'] ?? uploaded['imageUrl'])?.toString();
          if (imageUrl != null && imageUrl.trim().isNotEmpty && mounted) {
            setState(() {
              _roomsCreated = _roomsCreated.map((e) {
                if (e.id != newEvent.id) return e;
                return Event(
                  id: e.id,
                  title: e.title,
                  description: e.description,
                  imageUrl: imageUrl,
                  lat: e.lat,
                  lon: e.lon,
                  createdAt: e.createdAt,
                  markerColorValue: e.markerColorValue,
                  markerIconCodePoint: e.markerIconCodePoint,
                  rsvpStatus: e.rsvpStatus,
                  goingUsers: e.goingUsers,
                  notGoingUsers: e.notGoingUsers,
                  goingUserProfiles: e.goingUserProfiles,
                  notGoingUserProfiles: e.notGoingUserProfiles,
                  endsAt: e.endsAt,
                  creatorId: e.creatorId,
                  creatorEmail: e.creatorEmail,
                  creatorName: e.creatorName,
                );
              }).toList();
            });
          }
        } catch (_) {}
      }

      // Переключаемся на вкладку "Создал" чтобы увидеть новое событие
      _tabController.animateTo(1);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сервера: ${e.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать событие')),
      );
    }
  }

  String? _currentUserEmail() {
    final authBox = Hive.box('authBox');
    final email = authBox.get('email') as String?;
    if (email == null || email.trim().isEmpty) return null;
    return email.trim();
  }

  Widget _buildTabBody({
    required bool loading,
    required String? error,
    required List<Event> events,
    required String emptyMessage,
    required bool showCreateButton,
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
      // Определяем какую иконку показывать в зависимости от вкладки
      final isCreatedTab = showCreateButton;
      final assetPath = isCreatedTab
          ? 'assets/events/flag-dynamic-color.png'
          : 'assets/events/location-dynamic-color.png';
      final title = isCreatedTab
          ? 'Нет созданных событий'
          : 'Нет событий для участия';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(assetPath, width: 120, height: 120),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              if (showCreateButton) ...[
                const SizedBox(height: 32),
                _buildCreateEventButton(),
              ],
            ],
          ),
        ),
      );
    }

    // Сортируем события: предстоящие выше, завершенные ниже
    final sortedEvents = List<Event>.from(events);
    sortedEvents.sort((a, b) {
      final aIsEnded = a.endsAt != null && a.endsAt!.isBefore(DateTime.now());
      final bIsEnded = b.endsAt != null && b.endsAt!.isBefore(DateTime.now());

      if (aIsEnded == bIsEnded) {
        final aDate = a.endsAt ?? a.createdAt;
        final bDate = b.endsAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      }

      return aIsEnded ? 1 : -1;
    });

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: Colors.white,
      backgroundColor: const Color(0xFF161616),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: sortedEvents
            .map((event) => _buildEventListTile(event))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabBody(
                        loading: _loadingParticipating,
                        error: _errorParticipating,
                        events: _roomsParticipating,
                        emptyMessage:
                            'Вы пока не участвуете ни в одном событии.\nОтметьте «Я приду» в деталях события.',
                        showCreateButton: false,
                      ),
                      _buildTabBody(
                        loading: _loadingCreated,
                        error: _errorCreated,
                        events: _roomsCreated,
                        emptyMessage:
                            'Вы ещё не создавали событий.\nСоздайте событие на карте.',
                        showCreateButton: true,
                      ),
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

class _RoomMeta {
  const _RoomMeta({required this.unreadCount, required this.mutedUntil});

  final int unreadCount;
  final DateTime? mutedUntil;
}
