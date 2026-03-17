import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/event_marker_widget.dart';

class CreateEventLocationScreen extends StatefulWidget {
  const CreateEventLocationScreen({
    super.key,
    required this.initialCenter,
  });

  final LatLng initialCenter;

  @override
  State<CreateEventLocationScreen> createState() => _CreateEventLocationScreenState();
}

class _CreateEventLocationScreenState extends State<CreateEventLocationScreen> {
  final MapController _controller = MapController();
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите место'),
      ),
      body: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: widget.initialCenter,
          initialZoom: 13,
          backgroundColor: Colors.transparent,
          onPositionChanged: (position, hasGesture) {
            if (!hasGesture) return;
            final center = position.center;
            _selected = center;
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.event_app',
            tileProvider: CancellableNetworkTileProvider(),
          ),
          Center(
            child: IgnorePointer(
              child: const EventMarkerWidget(
                color: Colors.blue,
                icon: Icons.flutter_dash,
                size: 44,
                iconSize: 22,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _selected == null ? null : () => Navigator.of(context).pop(_selected),
              child: const Text('Далее'),
            ),
          ),
        ),
      ),
    );
  }
}

