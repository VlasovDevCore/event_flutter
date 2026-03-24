import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../../config/event_marker_catalog.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';
import '../../widgets/event_marker_widget.dart';
import '../../widgets/user_location_pulse_marker.dart';
import '../events/create_event_details_screen.dart';
import '../events/create_event_location_screen.dart';
import '../events/event_details_screen.dart';
import '../friends/friends_screen.dart';
import '../profile/profile_screen.dart';
import '../rooms/my_rooms_screen.dart';
import '../chat/direct_chat_picker_screen.dart';

import 'widgets/event_preview_card.dart';
import 'widgets/preview_participant.dart';
import 'widgets/visible_events_sheet_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  List<Event> _events = [];
  LatLng? _userPosition;
  List<Event> _visibleEvents = [];
  Event? _selectedEventPreview;
  bool _previewLoading = false;
  Timer? _visibleEventsDebounce;
  Timer? _geoMoveTimer;

  String? _currentUserEmail() {
    final authBox = Hive.box('authBox');
    final email = authBox.get('email') as String?;
    if (email == null || email.trim().isEmpty) return null;
    return email.trim();
  }

  bool _isCurrentUserGoing(Event event) {
    final me = _currentUserEmail();
    if (me == null) return event.rsvpStatus == 1;

    final inGoingUsers = event.goingUsers.any((e) => e.trim().toLowerCase() == me.toLowerCase());
    if (inGoingUsers) return true;

    final inGoingProfiles = event.goingUserProfiles.any((p) {
      final email = p.email;
      if (email == null) return false;
      return email.trim().toLowerCase() == me.toLowerCase();
    });
    if (inGoingProfiles) return true;

    final inNotGoingUsers = event.notGoingUsers.any((e) => e.trim().toLowerCase() == me.toLowerCase());
    if (inNotGoingUsers) return false;

    final inNotGoingProfiles = event.notGoingUserProfiles.any((p) {
      final email = p.email;
      if (email == null) return false;
      return email.trim().toLowerCase() == me.toLowerCase();
    });
    if (inNotGoingProfiles) return false;

    return event.rsvpStatus == 1;
  }

  @override
  void dispose() {
    _visibleEventsDebounce?.cancel();
    _geoMoveTimer?.cancel();
    _loadEventsDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadEventsFromApi();
    _initLocation(zoom: 13, immediateZoom: false);
  }

  void _animateMapTo(LatLng targetCenter, {required double zoom, Duration duration = const Duration(milliseconds: 650)}) {
    _geoMoveTimer?.cancel();

    final startCenter = _mapController.camera.center;
    final startLat = startCenter.latitude;
    final startLon = startCenter.longitude;
    final endLat = targetCenter.latitude;
    final endLon = targetCenter.longitude;

    final startTime = DateTime.now();
    final totalMs = duration.inMilliseconds.clamp(1, 100000);

    // ~60fps update loop
    const tickMs = 16;
    _geoMoveTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      final t = (elapsedMs / totalMs).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(t);

      final lat = startLat + (endLat - startLat) * eased;
      final lon = startLon + (endLon - startLon) * eased;

      _mapController.move(LatLng(lat, lon), zoom);

      if (t >= 1.0) {
        timer.cancel();
      }
    });
  }

  Future<void> _loadEventsFromApi() async {
    try {
      final client = ApiClient.instance;
      final items = await client.getList('/events');
      final events = _parseEventsFromJson(items);
      setState(() {
        _events = events;
      });
      _recomputeVisibleEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить события')),
      );
    }
  }

  List<Event> _parseEventsFromJson(List<dynamic> items) {
    return items.map((raw) {
      return Event.fromApiMap(Map<String, dynamic>.from(raw as Map));
    }).toList();
  }

  Timer? _loadEventsDebounce;

  void _debouncedLoadEventsByBounds(LatLngBounds bounds) {
    _loadEventsDebounce?.cancel();
    _loadEventsDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final bbox =
          '${bounds.southWest.longitude},${bounds.southWest.latitude},'
          '${bounds.northEast.longitude},${bounds.northEast.latitude}';
      try {
        final client = ApiClient.instance;
        final items = await client.getList('/events', query: {'bbox': bbox});
        final events = _parseEventsFromJson(items);
        if (!mounted) return;
        setState(() {
          _events = events;
        });
        _recomputeVisibleEvents();
      } catch (_) {
        // тихо игнорируем ошибки при подгрузке по движению карты
      }
    });
  }

  void _scheduleRecomputeVisibleEvents() {
    _visibleEventsDebounce?.cancel();
    _visibleEventsDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _recomputeVisibleEvents();
    });
  }

  void _recomputeVisibleEvents() {
    final bounds = _mapController.camera.visibleBounds;
    final next = _events.where((e) {
      final p = LatLng(e.lat, e.lon);
      return bounds.contains(p);
    }).toList();

    setState(() {
      _visibleEvents = next;
    });
  }

  List<PreviewParticipant> _participantsForEvent(Event event) {
    if (event.goingUserProfiles.isNotEmpty) {
      return event.goingUserProfiles
          .map(
            (p) => PreviewParticipant(
              label: p.displayName ?? p.username ?? p.email ?? 'U',
              avatarUrl: p.avatarUrl,
              status: p.status,
            ),
          )
          .toList();
    }

    return event.goingUsers
        .map(
          (name) => PreviewParticipant(
            label: name,
            avatarUrl: null,
            status: 1,
          ),
        )
        .toList();
  }

  Future<void> _openEventPreview(Event event) async {
    setState(() {
      _selectedEventPreview = event;
      _previewLoading = true;
    });

    try {
      final data = await ApiClient.instance.get('/events/${event.id}', withAuth: true);
      final loaded = Event.fromApiMap(data);

      if (!mounted) return;
      setState(() {
        _events = _events.map((e) => e.id == loaded.id ? loaded : e).toList();
        if (_selectedEventPreview != null && _selectedEventPreview!.id == loaded.id) {
          _selectedEventPreview = loaded;
        }
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
      });
    }
  }

  Future<void> _refreshEventById(String eventId) async {
    try {
      final data = await ApiClient.instance.get('/events/$eventId', withAuth: true);
      final loaded = Event.fromApiMap(data);
      if (!mounted) return;
      setState(() {
        _events = _events.map((e) => e.id == loaded.id ? loaded : e).toList();
        if (_selectedEventPreview != null && _selectedEventPreview!.id == loaded.id) {
          _selectedEventPreview = loaded;
        }
      });
    } catch (_) {
      // тихо игнорируем, чтобы не мешать UX при возврате с деталей
    }
  }

  Future<void> _updateRsvpStatus(Event event, int status) async {
    try {
      final client = ApiClient.instance;
      final data = await client.post(
        '/events/${event.id}/rsvp',
        body: {'status': status},
        withAuth: true,
      );

      final goingRaw = (data['going_users'] as List?) ?? const [];
      final notGoingRaw = (data['not_going_users'] as List?) ?? const [];

      List<EventUserProfile> parseProfiles(List raw) {
        return raw
            .where((e) => e is Map)
            .map((e) => EventUserProfile.fromApiMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      List<String> parseEmails(List raw) {
        return raw.map((e) {
          if (e is String) return e;
          if (e is Map && e['email'] != null) return e['email'].toString();
          return e.toString();
        }).toList();
      }

      int parseServerRsvpStatus(Map<String, dynamic> payload, int fallback) {
        int parseValue(dynamic value) {
          if (value == null) return 0;
          if (value is num) {
            if (value > 0) return 1;
            if (value < 0) return -1;
            return 0;
          }

          final normalized = value.toString().trim().toLowerCase();
          if (normalized.isEmpty) return 0;
          if (normalized == '1' ||
              normalized == 'true' ||
              normalized == 'going' ||
              normalized == 'yes' ||
              normalized == 'accepted') {
            return 1;
          }
          if (normalized == '-1' ||
              normalized == 'false' ||
              normalized == 'not_going' ||
              normalized == 'not-going' ||
              normalized == 'declined' ||
              normalized == 'no') {
            return -1;
          }
          final parsed = int.tryParse(normalized);
          if (parsed == null) return 0;
          if (parsed > 0) return 1;
          if (parsed < 0) return -1;
          return 0;
        }

        final candidates = [
          payload['rsvp_status'],
          payload['rsvpStatus'],
          payload['current_user_rsvp_status'],
          payload['currentUserRsvpStatus'],
          payload['my_rsvp_status'],
          payload['myRsvpStatus'],
          payload['status'],
        ];

        for (final value in candidates) {
          final parsed = parseValue(value);
          if (parsed != 0) return parsed;
        }

        return fallback;
      }

      final base = _events.firstWhere(
        (e) => e.id == event.id,
        orElse: () => event,
      );

      final updated = Event(
        id: base.id,
        title: base.title,
        description: base.description,
        lat: base.lat,
        lon: base.lon,
        createdAt: base.createdAt,
        markerColorValue: base.markerColorValue,
        markerIconCodePoint: base.markerIconCodePoint,
        rsvpStatus: parseServerRsvpStatus(data, status),
        goingUsers: parseEmails(goingRaw),
        notGoingUsers: parseEmails(notGoingRaw),
        goingUserProfiles: parseProfiles(goingRaw),
        notGoingUserProfiles: parseProfiles(notGoingRaw),
        endsAt: base.endsAt,
      );

      setState(() {
        _events = _events.map((e) => e.id == updated.id ? updated : e).toList();
        if (_selectedEventPreview != null && _selectedEventPreview!.id == updated.id) {
          _selectedEventPreview = updated;
        }
        _previewLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить участие')),
      );
    }
  }

  void _openVisibleEventsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 1.0,
          builder: (context, scrollController) {
            return VisibleEventsSheetContent(
              visibleEvents: _visibleEvents,
              scrollController: scrollController,
              sheetPadding: EdgeInsets.fromLTRB(
                0,
                8,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              onEventTap: (event) {
                Navigator.of(context).pop();
                _animateMapTo(
                  LatLng(event.lat, event.lon),
                  zoom: _mapController.camera.zoom,
                  duration: const Duration(milliseconds: 650),
                );

                Future.delayed(const Duration(milliseconds: 180), () {
                  _openEventPreview(event);
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _mapRoundIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    const background = Color(0xCC161616);
    const pressedBackground = Color(0xFF2C2E36);
    const foreground = Color(0xFFDFE3EC);
    const size = 56.0;
    const borderRadius = 20.0; // радиус скругления

    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed,
          splashColor: pressedBackground.withOpacity(0.5),
          highlightColor: pressedBackground,
          child: Center(
            child: Icon(icon, color: foreground),
          ),
        ),
      ),
    );
    
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Future<void> _initLocation({double zoom = 16, bool immediateZoom = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    if (!mounted) return;

    final targetZoom = _mapController.camera.zoom < zoom ? zoom : _mapController.camera.zoom;
    if (immediateZoom && _mapController.camera.zoom != targetZoom) {
      // Быстро "приближаем" карту, чтобы пользователь видел действие сразу.
      // Точный переход к координатам произойдёт после получения позиции.
      _mapController.move(_mapController.camera.center, targetZoom);
    }

    // 1) Сначала пытаемся быстро взять "кэшированную" позицию,
    // чтобы камера приближалась сразу, а не после долгого GPS фиксирования.
    final lastPosition = await Geolocator.getLastKnownPosition();

    if (lastPosition != null) {
      final userLatLng = LatLng(lastPosition.latitude, lastPosition.longitude);
      if (!mounted) return;

      setState(() {
        _userPosition = userLatLng;
      });

      _animateMapTo(userLatLng, zoom: targetZoom);
      _recomputeVisibleEvents();
    }

    // 2) Затем запрашиваем точные координаты и обновляем маркер/камеру.
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!mounted) return;
    final userLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _userPosition = userLatLng;
    });

    _animateMapTo(userLatLng, zoom: targetZoom);
    _recomputeVisibleEvents();
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
      final newEvent = Event(
        id: created['id'] as String,
        title: created['title'] as String,
        description: created['description'] as String? ?? '',
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
        endsAt: created['ends_at'] != null ? DateTime.parse(created['ends_at'] as String) : null,
        creatorId: created['created_by_user_id']?.toString(),
        creatorEmail: created['created_by_email']?.toString(),
        creatorName: (created['created_by_display_name'] ?? created['created_by_username'])
            ?.toString(),
      );

      setState(() {
        _events = [..._events, newEvent];
      });
      _recomputeVisibleEvents();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сервера: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать событие')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    const menuBarHeight = 64.0;
    const menuBarBottomInset = 12.0;
    final menuBottom = menuBarBottomInset + bottomPadding;
    final previewCardBottom = menuBottom + menuBarHeight;
    final newEventBottom = menuBottom + menuBarHeight + 0;
    final eventMarkers = _events.asMap().entries.map((entry) {
      final event = entry.value;
      final color = Color(event.markerColorValue);
      final icon = IconData(
        event.markerIconCodePoint,
        fontFamily: 'MaterialIcons',
      );

      return Marker(
        point: LatLng(event.lat, event.lon),
        width: 60,
        height: 60,
        rotate: true,
        child: Tooltip(
          message: event.title,
          child: GestureDetector(
            onTap: () => _openEventPreview(event),
            child: EventMarkerWidget(color: color, icon: icon),
          ),
        ),
      );
    }).toList();

    final userMarker = _userPosition == null
        ? <Marker>[]
        : [
            Marker(
              point: _userPosition!,
              width: UserLocationPulseMarker.size,
              height: UserLocationPulseMarker.size,
              alignment: Alignment.center,
              child: const UserLocationPulseMarker(),
            ),
          ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(55.751244, 37.618423),
              initialZoom: 11,
              minZoom: 10,
              backgroundColor: Colors.transparent,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (_, __) {
                if (_selectedEventPreview == null) return;
                setState(() {
                  _selectedEventPreview = null;
                  _previewLoading = false;
                });
              },
              onPositionChanged: (position, hasGesture) {
                _scheduleRecomputeVisibleEvents();
                if (hasGesture) {
                  final bounds = position.visibleBounds;
                  _debouncedLoadEventsByBounds(bounds);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: true,
                userAgentPackageName: 'com.example.event_app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: eventMarkers,
                  rotate: true,
                  maxClusterRadius: 60,
                  size: const Size(46, 46),
                  showPolygon: false,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
              MarkerLayer(markers: userMarker),
            ],
          ),
          Positioned(
            top: topPadding + 5,
            right: 10,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC161616),
                foregroundColor: const Color(0xFFDFE3EC),
                elevation: 0,
                padding: const EdgeInsets.all(10),
                iconSize: 22, 
              ),
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: topPadding + 10 + 48,
            right: 10,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC161616),
                foregroundColor: const Color(0xFFDFE3EC),
                elevation: 0,
                padding: const EdgeInsets.all(10),
                iconSize: 22, 
              ),
              icon: const Icon(Icons.my_location),
              onPressed: () {
                _initLocation(zoom: 16);
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: menuBottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _mapRoundIconButton(
                  icon: Icons.list,
                  onPressed: _openVisibleEventsSheet,
                ),
                _mapRoundIconButton(
                  icon: Icons.chat,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyRoomsScreen(),
                      ),
                    );
                  },
                ),
                _mapRoundIconButton(
                  icon: Icons.people,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FriendsScreen(),
                      ),
                    );
                  },
                ),
                _mapRoundIconButton(
                  icon: Icons.forum_outlined,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DirectChatPickerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: newEventBottom,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5F57), Color(0xFFFEBC2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomLeft,
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
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final initialCenter = _userPosition ?? _mapController.camera.center;
                    final selected = await navigator.push<LatLng>(
                      MaterialPageRoute(
                        builder: (_) => CreateEventLocationScreen(initialCenter: initialCenter),
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
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
          ),
         AnimatedOpacity(
            opacity: _selectedEventPreview == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: _selectedEventPreview == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, previewCardBottom),
                      child: Builder(
                        builder: (context) {
                          final event = _selectedEventPreview!;
                          final remaining = event.endsAt == null
                              ? null
                              : event.endsAt!.difference(DateTime.now());
                          String? remainingLabel;
                          if (remaining != null) {
                            if (remaining.inMinutes <= 0) {
                              remainingLabel = 'завершилось';
                            } else if (remaining.inHours < 1) {
                              remainingLabel = 'осталось ${remaining.inMinutes} мин';
                            } else if (remaining.inHours < 24) {
                              remainingLabel = 'осталось ${remaining.inHours} ч';
                            } else {
                              final days = remaining.inDays;
                              remainingLabel = 'осталось $days дн';
                            }
                          }

                          final participants = _participantsForEvent(event);
                          final totalGoing = participants.length;
                          final isGoing = _isCurrentUserGoing(event);
                          final iconLabel =
                              EventMarkerCatalog.categoryLabelForCodePoint(
                            event.markerIconCodePoint,
                          );
                          final markerColor = Color(event.markerColorValue);

                          return EventPreviewCard(
                            event: event,
                            previewLoading: _previewLoading,
                            remainingLabel: remainingLabel,
                            iconLabel: iconLabel,
                            markerColor: markerColor,
                            participants: participants,
                            totalGoing: totalGoing,
                            isGoing: isGoing,
                            onRsvpToggle: (status) => _updateRsvpStatus(event, status),
                            onOpenDetails: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => EventDetailsScreen(event: event),
                                    ),
                                  )
                                  .then((_) => _refreshEventById(event.id));
                            },
                          );
                        },
                      ),
                    ),
                  ),
          )
        ],
      ),
      
    );
  }
}


