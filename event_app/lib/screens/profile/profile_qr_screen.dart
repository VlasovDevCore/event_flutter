import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileQrScreen extends StatefulWidget {
  const ProfileQrScreen({
    super.key,
    required this.userId,
    required this.buildProfileScreen,
  });

  final String userId;
  final Widget Function(String userId) buildProfileScreen;

  @override
  State<ProfileQrScreen> createState() => _ProfileQrScreenState();
}

class _ProfileQrScreenState extends State<ProfileQrScreen> {
  bool _opened = false;

  String? _extractUserId(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    // New deep-link format: eventapp://profile?userId=...
    if (value.startsWith('eventapp://')) {
      try {
        final uri = Uri.parse(value);
        if (uri.scheme == 'eventapp' && uri.host == 'profile') {
          final userId = uri.queryParameters['userId'];
          if (userId != null && userId.trim().isNotEmpty) return userId.trim();
        }
      } catch (_) {
        // ignore
      }
      return null;
    }

    // Backward compatibility: QR contains just userId.
    return value;
  }

  void _handleScanned(String? raw) {
    if (_opened) return;
    final value = _extractUserId(raw);
    if (value == null || value.isEmpty) return;
    _opened = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => widget.buildProfileScreen(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrSize = 260.0;
    final fg = Theme.of(context).colorScheme.primary;
    final bg = Theme.of(context).colorScheme.surface;
    // This is what we encode into the QR, so that normal scanners can open the app.
    final qrPayload = 'eventapp://profile?userId=${widget.userId}';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'QR пользователя'),
              Tab(text: 'Камера'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: qrSize,
                      height: qrSize,
                      decoration: BoxDecoration(
                        color: bg,
                        border: Border.all(color: fg, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: QrImageView(
                          data: qrPayload,
                          version: QrVersions.auto,
                          size: qrSize - 12,
                          foregroundColor: fg,
                          backgroundColor: bg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Откроет профиль по: ${widget.userId}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    // rawValue can be null if code type is not supported.
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    for (final b in barcodes) {
                      _handleScanned(b.rawValue);
                      if (_opened) break;
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: qrSize,
                    height: qrSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_opened)
                  const Center(
                    child: Text(
                      'Профиль открывается...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

