import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../models/event.dart';
import '../services/api_client.dart';
import '../screens/create_event_details_screen.dart';
import '../screens/create_event_location_screen.dart';
import 'event_details_screen.dart';
import 'friends_screen.dart';
import 'my_rooms_screen.dart';
import '../widgets/event_marker_widget.dart';

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
  Timer? _visibleEventsDebounce;

  @override
  void dispose() {
    _visibleEventsDebounce?.cancel();
    _loadEventsDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadEventsFromApi();
    _initLocation();
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
          markerColorValue:
              int.parse(map['marker_color_value'].toString()), // bigint -> string
          markerIconCodePoint:
              int.parse(map['marker_icon_code'].toString()),
          rsvpStatus: 0,
          goingUsers: const [],
          notGoingUsers: const [],
          endsAt: map['ends_at'] != null
              ? DateTime.parse(map['ends_at'] as String)
              : null,
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

  void _openVisibleEventsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'События на экране: ${_visibleEvents.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _visibleEvents.isEmpty
                      ? Center(
                          child: Text(
                            'На текущем экране событий нет',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _visibleEvents.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final event = _visibleEvents[index];
                            final color = Color(event.markerColorValue);
                            final icon = IconData(
                              event.markerIconCodePoint,
                              fontFamily: 'MaterialIcons',
                            );

                            return ListTile(
                              leading: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: EventMarkerWidget(
                                    color: color,
                                    icon: icon,
                                    size: 28,
                                    iconSize: 16,
                                  ),
                                ),
                              ),
                              title: Text(event.title),
                              subtitle: Text(
                                '${event.lat.toStringAsFixed(5)}, ${event.lon.toStringAsFixed(5)}',
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EventDetailsScreen(event: event),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final userLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _userPosition = userLatLng;
    });

    _mapController.move(userLatLng, 13);
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
        markerColorValue:
            int.parse(created['marker_color_value'].toString()),
        markerIconCodePoint:
            int.parse(created['marker_icon_code'].toString()),
        rsvpStatus: 0,
        goingUsers: const [],
        notGoingUsers: const [],
        endsAt: created['ends_at'] != null
            ? DateTime.parse(created['ends_at'] as String)
            : null,
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

  Future<void> _logout() async {
    final authBox = Hive.box('authBox');
    await authBox.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final eventMarkers = _events.asMap().entries.map((entry) {
      final event = entry.value;
      final color = Color(event.markerColorValue);
      final icon = IconData(
        event.markerIconCodePoint,
        fontFamily: 'MaterialIcons',
      );

      return Marker(
        point: LatLng(event.lat, event.lon),
        width: 44,
        height: 44,
        child: Tooltip(
          message: event.title,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailsScreen(event: event),
                ),
              );
            },
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
      appBar: AppBar(
        title: const Text('События на карте'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(55.751244, 37.618423), // Москва
          initialZoom: 11,
          backgroundColor: Colors.transparent,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
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
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final initialCenter = _userPosition ?? _mapController.camera.center;
          final selected = await Navigator.of(context).push<LatLng>(
            MaterialPageRoute(
              builder: (_) => CreateEventLocationScreen(initialCenter: initialCenter),
            ),
          );
          if (selected == null) return;

          final created = await Navigator.of(context).push<Event>(
            MaterialPageRoute(
              builder: (_) => CreateEventDetailsScreen(position: selected),
            ),
          );
          if (created == null) return;

          await _addEvent(created);
        },
        icon: const Icon(Icons.add),
        label: const Text('Новое событие'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openVisibleEventsSheet,
                  icon: const Icon(Icons.list),
                  label: Text('События на экране (${_visibleEvents.length})'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyRoomsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Комнаты, где я участвую'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FriendsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('Мои друзья'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

