import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

const Color _kBg = Color(0xFF161616);
const Color _kSurface = Color(0xFF232323);
const Color _kAccent = Color(0xFF007AFF);

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
    const qrSize = 260.0;
    final qrPayload = 'eventapp://profile?userId=${widget.userId}';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'QR профиля',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: _kAccent,
            indicatorWeight: 3,
            dividerColor: Color(0xFF2C2C2C),
            labelStyle: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'Мой QR'),
              Tab(text: 'Сканер'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: qrSize,
                      height: qrSize,
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColoredBox(
                          color: Colors.white,
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: qrSize - 32,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Покажите код — откроется профиль в приложении',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${widget.userId}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    for (final b in barcodes) {
                      _handleScanned(b.rawValue);
                      if (_opened) break;
                    }
                  },
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                        stops: const [0.0, 0.15, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: qrSize,
                    height: qrSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _kAccent.withValues(alpha: 0.9),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_opened)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        'Профиль открывается…',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
