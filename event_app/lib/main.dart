import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 Добавьте этот импорт
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';

import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: иначе на Android 15+ стиль статус-бара может сбрасываться.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Светлые (белые) иконки часов/сети/батареи на тёмном фоне.
  // В Flutter: Brightness.dark = светлые иконки; Brightness.light = тёмные.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await Hive.initFlutter();
  await Hive.openBox('authBox');
  await Hive.openBox('eventsBox');

  runApp(const EventApp());
}

class EventApp extends StatefulWidget {
  const EventApp({super.key});

  @override
  State<EventApp> createState() => _EventAppState();
}

class _EventAppState extends State<EventApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  Future<void> _handleUri(Uri uri) async {
    if (uri.scheme != 'eventapp' || uri.host != 'profile') return;
    final userId = uri.queryParameters['userId']?.trim();
    if (userId == null || userId.isEmpty) return;

    final authBox = Hive.box('authBox');
    final token = authBox.get('token') as String?;
    final isLoggedIn = token != null && token.isNotEmpty;

    if (!isLoggedIn) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        (route) => false,
      );
      return;
    }

    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => ProfileScreen(userId: userId)),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();

    _appLinks.getInitialLink().then((uri) async {
      if (uri == null) return;
      await _handleUri(uri);
    });

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authBox = Hive.box('authBox');
    final token = authBox.get('token') as String?;
    final isLoggedIn = token != null && token.isNotEmpty;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Events',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.dark,
            systemStatusBarContrastEnforced: false,
          ),
        ),
      ),
      home: isLoggedIn ? const HomeScreen() : const AuthScreen(),
    );
  }
}
