import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../config/event_marker_catalog.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';
import '../../widgets/event_marker_widget.dart';
import '../events/create_event_details_screen.dart';
import '../events/create_event_location_screen.dart';
import '../events/event_details_screen.dart';
import '../friends/friends_screen.dart';
import '../profile/profile_screen.dart';
import '../rooms/my_rooms_screen.dart';

import 'widgets/event_preview_card.dart';
import 'widgets/preview_participant.dart';
import 'widgets/visible_events_sheet_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum PreviewPlacement {
  bottom,
  center,
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  List<Event> _events = [];
  LatLng? _userPosition;
  List<Event> _visibleEvents = [];
  Event? _selectedEventPreview;
  bool _previewLoading = false;
  PreviewPlacement _previewPlacement = PreviewPlacement.bottom;
  Timer? _visibleEventsDebounce;
  Timer? _geoMoveTimer;

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
    _initLocation();
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
      final map = raw as Map<String, dynamic>;
      return Event(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String? ?? '',
        lat: (map['lat'] as num).toDouble(),
        lon: (map['lon'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        markerColorValue: int.parse(map['marker_color_value'].toString()),
        markerIconCodePoint: int.parse(map['marker_icon_code'].toString()),
        rsvpStatus: 0,
        goingUsers: const [],
        notGoingUsers: const [],
        goingUserProfiles: const [],
        notGoingUserProfiles: const [],
        endsAt: map['ends_at'] != null ? DateTime.parse(map['ends_at'] as String) : null,
      );
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

  Future<void> _openEventPreview(
    Event event, {
    PreviewPlacement placement = PreviewPlacement.bottom,
  }) async {
    setState(() {
      _selectedEventPreview = event;
      _previewPlacement = placement;
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
        rsvpStatus: status,
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
      enableDrag: false,
      showDragHandle: false,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.45,
          maxChildSize: 0.45,
          builder: (context, scrollController) {
            return VisibleEventsSheetContent(
              visibleEvents: _visibleEvents,
              scrollController: scrollController,
              onEventTap: (event) {
                Navigator.of(context).pop();
                // Делаем так, чтобы маркер был по центру экрана,
                // а затем показываем мини-карточку события по центру.
                _animateMapTo(
                  LatLng(event.lat, event.lon),
                  zoom: _mapController.camera.zoom,
                  duration: const Duration(milliseconds: 650),
                );

                Future.delayed(const Duration(milliseconds: 180), () {
                  _openEventPreview(event, placement: PreviewPlacement.bottom);
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
  }) {
    const background = Color(0xFF151922);
    const foreground = Color(0xFFDFE3EC);
    const size = 56.0;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(size / 2)),
          onTap: onPressed,
          child: Center(child: Icon(icon, color: foreground)),
        ),
      ),
    );
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final userLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _userPosition = userLatLng;
    });

    _animateMapTo(userLatLng, zoom: 13);
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

      final newEvent = Event(
        id: created['id'] as String,
        title: created['title'] as String,
        description: created['description'] as String? ?? '',
        lat: (created['lat'] as num).toDouble(),
        lon: (created['lon'] as num).toDouble(),
        createdAt: DateTime.parse(created['created_at'] as String),
        markerColorValue: int.parse(created['marker_color_value'].toString()),
        markerIconCodePoint: int.parse(created['marker_icon_code'].toString()),
        rsvpStatus: 0,
        goingUsers: const [],
        notGoingUsers: const [],
        goingUserProfiles: const [],
        notGoingUserProfiles: const [],
        endsAt: created['ends_at'] != null ? DateTime.parse(created['ends_at'] as String) : null,
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
    final previewCardBottom = menuBottom + menuBarHeight + 90;
    final newEventBottom = menuBottom + menuBarHeight + 12;
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
              width: 40,
              height: 40,
              child: Container(
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
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 22,
                ),
              ),
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
              backgroundColor: Colors.transparent,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (_, __) {
                if (_selectedEventPreview == null) return;
                setState(() {
                  _selectedEventPreview = null;
                  _previewLoading = false;
                  _previewPlacement = PreviewPlacement.bottom;
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
                  maxClusterRadius: 60,
                  size: const Size(46, 46),
                  showPolygon: false,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
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
                          color: Colors.white,
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
          AnimatedOpacity(
            opacity: _selectedEventPreview == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: _selectedEventPreview == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: _previewPlacement == PreviewPlacement.center
                        ? Alignment.center
                        : Alignment.bottomCenter,
                    child: Padding(
                      padding: _previewPlacement == PreviewPlacement.bottom
                          ? EdgeInsets.fromLTRB(16, 0, 16, previewCardBottom)
                          : const EdgeInsets.symmetric(horizontal: 16),
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
                          final isGoing = event.rsvpStatus == 1;
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
          ),
          Positioned(
            top: topPadding + 10,
            right: 10,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF151922),
                foregroundColor: const Color(0xFFDFE3EC),
                elevation: 0,
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.person),
              tooltip: 'Профиль',
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
            top: topPadding + 10 + 58,
            right: 10,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF151922),
                foregroundColor: const Color(0xFFDFE3EC),
                elevation: 0,
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.my_location),
              tooltip: 'Геопозиция',
              onPressed: () async {
                await _initLocation();
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
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
                  icon: Icons.circle_outlined,
                  onPressed: null, // заглушка
                ),
              ],
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: newEventBottom,
            child: Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
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
                icon: const Icon(Icons.add),
                label: const Text('Новое событие'),
              ),
            ),
          ),
        ],
      ),
      
    );
  }
}


