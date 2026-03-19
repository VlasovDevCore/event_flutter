import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class AvatarCropDialog extends StatefulWidget {
  const AvatarCropDialog({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<AvatarCropDialog> {
  double _offsetX = 0;
  double _offsetY = 0;
  double _zoom = 1.0;

  // Calculated after decode.
  double _viewport = 260;
  double _imgW = 0;
  double _imgH = 0;
  double _minSide = 0;

  late final Future<ui.Image> _decodeFuture;

  Future<ui.Image> _decodeFromBytes(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }

  @override
  void initState() {
    super.initState();
    _decodeFuture = _decodeFromBytes(widget.bytes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _decodeFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || !snap.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final img = snap.data!;

        _imgW = img.width.toDouble();
        _imgH = img.height.toDouble();
        _minSide = _imgW < _imgH ? _imgW : _imgH;
        _viewport = (MediaQuery.of(context).size.width * 0.78).clamp(200.0, 320.0);

        final baseScale = _viewport / _minSide;
        final displayScale = baseScale * _zoom;
        final scaledW = _imgW * displayScale;
        final scaledH = _imgH * displayScale;

        final maxOffsetX = ((scaledW - _viewport).clamp(0, double.infinity)) / 2.0;
        final maxOffsetY = ((scaledH - _viewport).clamp(0, double.infinity)) / 2.0;

        final clampedOffsetX = _offsetX.clamp(-maxOffsetX, maxOffsetX);
        final clampedOffsetY = _offsetY.clamp(-maxOffsetY, maxOffsetY);

        return AlertDialog(
          title: const Text('Обрезка аватарки'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Container(
                  width: _viewport,
                  height: _viewport,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: GestureDetector(
                    onScaleStart: (_) {},
                    onScaleUpdate: (details) {
                      setState(() {
                        if (_minSide <= 0) return;

                        final nextZoom = (_zoom * details.scale).clamp(1.0, 3.0);
                        final baseScale = _viewport / _minSide;
                        final displayScale = baseScale * nextZoom;

                        final scaledW = _imgW * displayScale;
                        final scaledH = _imgH * displayScale;

                        final maxOffsetX =
                            ((scaledW - _viewport).clamp(0, double.infinity)) / 2.0;
                        final maxOffsetY =
                            ((scaledH - _viewport).clamp(0, double.infinity)) / 2.0;

                        _zoom = nextZoom;
                        _offsetX =
                            (_offsetX + details.focalPointDelta.dx).clamp(-maxOffsetX, maxOffsetX);
                        _offsetY =
                            (_offsetY + details.focalPointDelta.dy).clamp(-maxOffsetY, maxOffsetY);
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Centered image; we move it under a fixed circular viewport.
                        Transform.translate(
                          offset: Offset(clampedOffsetX, clampedOffsetY),
                          child: Image.memory(
                            widget.bytes,
                            width: scaledW,
                            height: scaledH,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Потяните изображение для позиции, используйте два пальца для приближения',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _offsetX = 0;
                _offsetY = 0;
                _zoom = 1.0;
              }),
              child: const Text('Центр'),
            ),
            FilledButton(
              onPressed: () async {
                final outputPx = 512;

                final baseScale2 = _viewport / _minSide;
                final displayScale2 = baseScale2 * _zoom;
                final scaledW2 = img.width * displayScale2;
                final scaledH2 = img.height * displayScale2;

                final maxOffsetX2 = ((scaledW2 - _viewport).clamp(0, double.infinity)) / 2.0;
                final maxOffsetY2 = ((scaledH2 - _viewport).clamp(0, double.infinity)) / 2.0;

                final clampedOffsetX2 = _offsetX.clamp(-maxOffsetX2, maxOffsetX2);
                final clampedOffsetY2 = _offsetY.clamp(-maxOffsetY2, maxOffsetY2);

                final x02 = (_viewport - scaledW2) / 2.0 + clampedOffsetX2;
                final y02 = (_viewport - scaledH2) / 2.0 + clampedOffsetY2;

                final sourceSize = _viewport / displayScale2;

                final sourceLeft = (-x02) / displayScale2;
                final sourceTop = (-y02) / displayScale2;

                final maxLeft = img.width.toDouble() - sourceSize;
                final maxTop = img.height.toDouble() - sourceSize;

                final clampedLeft = sourceLeft.clamp(0.0, maxLeft);
                final clampedTop = sourceTop.clamp(0.0, maxTop);

                final src = ui.Rect.fromLTWH(clampedLeft, clampedTop, sourceSize, sourceSize);
                final recorder = ui.PictureRecorder();
                final canvas = ui.Canvas(recorder);
                final paint = ui.Paint()..isAntiAlias = true;

                canvas.drawImageRect(
                  img,
                  src,
                  ui.Rect.fromLTWH(0, 0, outputPx.toDouble(), outputPx.toDouble()),
                  paint,
                );

                final picture = recorder.endRecording();
                final croppedImage = await picture.toImage(outputPx, outputPx);
                final data = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

                if (!context.mounted) return;
                Navigator.of(context).pop(data?.buffer.asUint8List());
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }
}

