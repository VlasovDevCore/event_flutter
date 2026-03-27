import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../../widgets/event_marker_widget.dart';
import 'search_location_screen.dart';

class CreateEventLocationScreen extends StatefulWidget {
  const CreateEventLocationScreen({super.key, required this.initialCenter});

  final LatLng initialCenter;

  @override
  State<CreateEventLocationScreen> createState() =>
      _CreateEventLocationScreenState();
}

class _CreateEventLocationScreenState extends State<CreateEventLocationScreen> {
  final MapController _controller = MapController();
  LatLng? _selected;
  String? _currentAddress;
  bool _isFirstLoad = true; // Флаг для первой загрузки
  Timer? _addressDebounce;
  bool _isLoadingLocation = false;
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
    _updateAddress(widget.initialCenter);
    _loadUserPosition();
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUserPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Ошибка загрузки позиции: $e');
    }
  }

  Future<void> _moveToMyLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Включите геолокацию')));
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Разрешите доступ к геолокации')),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Доступ к геолокации заблокирован')),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _selected = location;
        _userPosition = location;
        _isFirstLoad = false;
      });

      _animateMapTo(location, zoom: 15);
      _updateAddress(location);
    } catch (e) {
      print('Ошибка геолокации: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось определить местоположение')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _animateMapTo(LatLng targetCenter, {required double zoom}) {
    final startCenter = _controller.camera.center;
    final startLat = startCenter.latitude;
    final startLon = startCenter.longitude;
    final endLat = targetCenter.latitude;
    final endLon = targetCenter.longitude;

    final startTime = DateTime.now();
    const duration = Duration(milliseconds: 650);
    const tickMs = 16;

    Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      final t = (elapsedMs / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(t);

      final lat = startLat + (endLat - startLat) * eased;
      final lon = startLon + (endLon - startLon) * eased;

      _controller.move(LatLng(lat, lon), zoom);

      if (t >= 1.0) {
        timer.cancel();
      }
    });
  }

  Future<void> _updateAddress(LatLng position) async {
    if (_addressDebounce?.isActive ?? false) _addressDebounce?.cancel();

    _addressDebounce = Timer(const Duration(milliseconds: 300), () async {
      // Показываем, что адрес загружается, но без кружка
      if (!_isFirstLoad) {
        setState(() {});
      }

      try {
        final address = await _getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (mounted) {
          setState(() {
            _currentAddress = address ?? 'Неизвестное место';
            _isFirstLoad = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _currentAddress = 'Не удалось определить';
            _isFirstLoad = false;
          });
        }
      }
    });
  }

  Future<String?> _getAddressFromCoordinates(double lat, double lon) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse'
              '?lat=$lat&lon=$lon'
              '&format=json'
              '&accept-language=ru'
              '&addressdetails=1'
              '&zoom=19',
            ),
            headers: {'User-Agent': 'EventApp/1.0'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        final militaryPattern = RegExp(r'^[0-9]+[A-Z]-[0-9]+$');

        String street =
            address['road'] ??
            address['pedestrian'] ??
            address['footway'] ??
            '';

        if (militaryPattern.hasMatch(street)) {
          street = '';
        }

        String house = address['house_number'] ?? '';
        String city =
            address['city'] ?? address['town'] ?? address['village'] ?? '';

        if (street.isNotEmpty && house.isNotEmpty) {
          return '$street, $house • $city';
        } else if (street.isNotEmpty) {
          return '$street • $city';
        } else if (city.isNotEmpty) {
          return city;
        }

        final displayName = data['display_name'] ?? '';
        if (militaryPattern.hasMatch(displayName)) {
          if (city.isNotEmpty) return city;
          final region = address['county'] ?? address['state'] ?? '';
          if (region.isNotEmpty) return region;
          return 'Точка на карте';
        }

        return displayName.split(',')[0] ?? 'Неизвестно';
      }
    } catch (e) {
      print('Ошибка геокодинга: $e');
    }
    return null;
  }

  Future<void> _searchPlace() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SearchLocationScreen()),
    );

    if (result != null && mounted) {
      final lat = result['lat'] as double;
      final lon = result['lon'] as double;
      final location = LatLng(lat, lon);

      setState(() {
        _selected = location;
        _currentAddress = null;
        _isFirstLoad = false;
      });

      _animateMapTo(location, zoom: 15);
      _updateAddress(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final List<Marker> markers = [];

    if (_userPosition != null) {
      markers.add(
        Marker(
          point: _userPosition!,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.my_location, color: Colors.blue, size: 20),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 13,
              backgroundColor: Colors.transparent,
              onPositionChanged: (position, hasGesture) {
                if (!hasGesture) return;
                final center = position.center;
                _selected = center;
                _currentAddress = null;
                _isFirstLoad = false;
                _updateAddress(center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: true,
                userAgentPackageName: 'com.example.event_app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              MarkerLayer(markers: markers),
              Center(
                child: IgnorePointer(
                  child: const EventMarkerWidget(
                    color: Color(0xFF4D4DFF),
                    icon: Icons.add_location,
                    size: 50,
                    iconSize: 24,
                  ),
                ),
              ),
            ],
          ),
          // Градиент сверху слева
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 180,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Верхняя панель с адресом и кнопками справа
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Текст адреса (слева) с анимацией появления
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: _currentAddress == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  _currentAddress!,
                                  key: ValueKey(_currentAddress),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Кнопки справа в столбик
                  Column(
                    children: [
                      // Кнопка назад (стрелка)
                      Tooltip(
                        message: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xCC161616),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.of(context).maybePop(),
                              splashColor: const Color.fromARGB(157, 0, 0, 0),
                              highlightColor: const Color.fromARGB(
                                157,
                                0,
                                0,
                                0,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Кнопка поиска
                      Tooltip(
                        message: 'Поиск места',
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xCC161616),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _searchPlace,
                              splashColor: const Color.fromARGB(157, 0, 0, 0),
                              highlightColor: const Color.fromARGB(
                                157,
                                0,
                                0,
                                0,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Кнопка геолокации
                      Tooltip(
                        message: 'Моё местоположение',
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xCC161616),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _isLoadingLocation
                                  ? null
                                  : _moveToMyLocation,
                              splashColor: const Color.fromARGB(157, 0, 0, 0),
                              highlightColor: const Color.fromARGB(
                                157,
                                0,
                                0,
                                0,
                              ),
                              child: Center(
                                child: _isLoadingLocation
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Нижняя кнопка "Далее"
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Далее'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
