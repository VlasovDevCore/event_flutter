import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/event.dart';

class AddEventDialog extends StatefulWidget {
  const AddEventDialog({
    super.key,
    required this.mapController,
  });

  final MapController mapController;

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  LatLng? _position;

  @override
  void initState() {
    super.initState();
    _position = widget.mapController.camera.center;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTapMap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _position = latLng;
    });
  }

  void _submit() {
    if (_position == null) return;
    if (!_formKey.currentState!.validate()) return;

    final uuid = const Uuid();
    final event = Event(
      id: uuid.v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      lat: _position!.latitude,
      lon: _position!.longitude,
      createdAt: DateTime.now(),
      markerColorValue: 0xFF2196F3,
      markerIconCodePoint: 0xE1C7, // Icons.flutter_dash
      rsvpStatus: 0,
      goingUsers: const [],
      notGoingUsers: const [],
      goingUserProfiles: const [],
      notGoingUserProfiles: const [],
    );

    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новое событие'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _position ?? const LatLng(55.751244, 37.618423),
                    initialZoom: 13,
                    onTap: _onTapMap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      retinaMode: true,
                      userAgentPackageName: 'com.example.event_app',
                      tileProvider: CancellableNetworkTileProvider(),
                    ),
                    if (_position != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _position!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Заголовок',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите заголовок';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Описание',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

