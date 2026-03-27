import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'profile_avatar.dart';
import 'profile_cover_gradient.dart';

const Color _kBg = Color.fromARGB(100, 22, 22, 22);
const Color _kSurface = Color.fromARGB(100, 35, 35, 35);

class ProfileQrScreen extends StatefulWidget {
  const ProfileQrScreen({
    super.key,
    required this.userId,
    required this.buildProfileScreen,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.coverGradientColors,
  });

  final String userId;
  final Widget Function(String userId) buildProfileScreen;
  final String? displayName;
  final String? username;
  final String? avatarUrl;

  /// Три цвета градиента обложки (`#RRGGBB`), как в API / Hive.
  final List<String>? coverGradientColors;

  @override
  State<ProfileQrScreen> createState() => _ProfileQrScreenState();
}

class _ProfileQrScreenState extends State<ProfileQrScreen> {
  static const Color _kCopiedGreen = Color(0xFF34C759);

  bool _nickCopied = false;
  Timer? _copyResetTimer;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  String get _qrPayload => 'eventapp://profile?userId=${widget.userId}';

  String get _nameLine {
    final n = widget.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final u = widget.username?.trim();
    if (u != null && u.isNotEmpty) return u;
    return 'Профиль';
  }

  String get _nicknameLine {
    final u = widget.username?.trim();
    if (u != null && u.isNotEmpty) return '@$u';
    return '—';
  }

  String? get _nicknameForClipboard {
    final u = widget.username?.trim();
    if (u == null || u.isEmpty) return null;
    return '@$u';
  }

  void _openScanner(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ProfileQrScannerPage(
          buildProfileScreen: widget.buildProfileScreen,
        ),
      ),
    );
  }

  Future<void> _copyNickname(BuildContext context) async {
    final text = _nicknameForClipboard;
    if (text == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ник не указан', style: TextStyle(fontFamily: 'Inter')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    setState(() => _nickCopied = true);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _nickCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const qrSize = 260.0;
    final resolvedAvatar = resolveAvatarUrl(widget.avatarUrl);
    final g = coverGradientColorsFromHex(widget.coverGradientColors);
    final c0 = g[0];
    final c1 = g[1];
    final c2 = g[2];

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _kBg),
          // Основной градиент от правого верхнего угла до левого нижнего (только 3 цвета)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [c0, c1, c2],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Нижний затемняющий градиент
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    _kBg.withValues(alpha: 0.32),
                    _kBg,
                  ],
                  stops: const [0.0, 0.32, 0.82, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 16, 8),
                  child: Row(
                    children: [
                      Tooltip(
                        message: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
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
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'QR профиля',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Container(
                                width: qrSize,
                                height: qrSize,
                                decoration: BoxDecoration(
                                  color: _kBg,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
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
                                      data: _qrPayload,
                                      version: QrVersions.auto,
                                      size: qrSize - 32,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Colors.black,
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Material(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _copyNickname(context),
                      borderRadius: BorderRadius.circular(26),
                      splashColor: Colors.black.withValues(alpha: 0.32),
                      highlightColor: Colors.black.withValues(alpha: 0.18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: ColoredBox(
                                  color: _kBg,
                                  child: resolvedAvatar != null
                                      ? Image.network(
                                          resolvedAvatar,
                                          fit: BoxFit.cover,
                                          width: 56,
                                          height: 56,
                                          errorBuilder: (_, _, _) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.person,
                                                  color: Colors.white70,
                                                  size: 30,
                                                ),
                                              ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white70,
                                            size: 30,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nameLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _nicknameLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _copyNickname(context),
                              style: IconButton.styleFrom(
                                foregroundColor: _nickCopied
                                    ? _kCopiedGreen
                                    : Colors.white,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                              ),
                              icon: Icon(
                                _nickCopied
                                    ? Icons.check_rounded
                                    : Icons.copy_rounded,
                                color: _nickCopied
                                    ? _kCopiedGreen
                                    : Colors.white,
                              ),
                              tooltip: _nickCopied
                                  ? 'Скопировано'
                                  : 'Копировать ник',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _openScanner(context),
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.black,
                      ),
                      label: const Text(
                        'Открыть QR-сканер',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ),
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

class _ProfileQrScannerPage extends StatefulWidget {
  const _ProfileQrScannerPage({required this.buildProfileScreen});

  final Widget Function(String userId) buildProfileScreen;

  @override
  State<_ProfileQrScannerPage> createState() => _ProfileQrScannerPageState();
}

class _ProfileQrScannerPageState extends State<_ProfileQrScannerPage> {
  late final MobileScannerController _scannerController =
      MobileScannerController();
  bool _opened = false;

  String? _extractUserId(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

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

    return value;
  }

  void _handleScanned(String? raw) {
    if (_opened) return;
    final value = _extractUserId(raw);
    if (value == null || value.isEmpty) return;
    _opened = true;
    _scannerController.stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => widget.buildProfileScreen(value)),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const qrSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              for (final b in barcodes) {
                _handleScanned(b.rawValue);
                if (_opened) break;
              }
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.78),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.28, 0.58],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
                child: Row(
                  children: [
                    Tooltip(
                      message: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
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
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Сканирование',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: qrSize,
              height: qrSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
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
    );
  }
}
