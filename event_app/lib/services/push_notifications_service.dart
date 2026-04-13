import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/event.dart';
import '../navigation/app_navigator.dart';
import '../screens/chat/direct_chat_screen.dart';
import '../screens/chat/event_chat_screen.dart';
import '../screens/events/event_details_screen.dart';
import 'api_client.dart';
import 'chat_presence_tracker.dart';

const AndroidNotificationChannel _androidChatChannel = AndroidNotificationChannel(
  'chat_messages',
  'Сообщения',
  description: 'Уведомления о новых сообщениях в личных чатах и чатах событий',
  importance: Importance.high,
);

Future<void> _openEventChatFromId(String eventId) async {
  try {
    final data = await ApiClient.instance.get('/events/$eventId', withAuth: true);
    final event = Event.fromApiMap(data);
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => EventChatScreen(event: event),
      ),
    );
  } catch (_) {}
}

Future<void> _openEventDetailsFromId(String eventId) async {
  try {
    final data = await ApiClient.instance.get('/events/$eventId', withAuth: true);
    final event = Event.fromApiMap(data);
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailsScreen(event: event),
      ),
    );
  } catch (_) {}
}

void _handleOpenFromData(Map<String, dynamic> data) {
  final type = data['type']?.toString();
  if (type == 'direct') {
    final peerId = data['peer_id']?.toString();
    if (peerId == null || peerId.isEmpty) return;
    final title = data['sender_name']?.toString().trim();
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => DirectChatScreen(
            userId: peerId,
            title: (title != null && title.isNotEmpty) ? title : 'Чат',
          ),
        ),
      ),
    );
  } else if (type == 'event') {
    final eventId = data['event_id']?.toString();
    if (eventId == null || eventId.isEmpty) return;
    unawaited(_openEventChatFromId(eventId));
  } else if (type == 'new_event') {
    final eventId = data['event_id']?.toString();
    if (eventId == null || eventId.isEmpty) return;
    unawaited(_openEventDetailsFromId(eventId));
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Регистрация FCM, локальные уведомления в foreground, отправка токена на бэкенд.
class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance = PushNotificationsService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  Future<void> bootstrap() async {
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      debugPrint('Firebase.initializeApp: $e\n$st');
      return;
    }

    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleOpenFromData(Map<String, dynamic>.from(message.data));
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleOpenFromData(Map<String, dynamic>.from(initial.data));
      });
    }

    messaging.onTokenRefresh.listen((t) {
      _fcmToken = t;
      unawaited(_sendTokenToBackend(t));
    });

    final token = await messaging.getToken();
    _fcmToken = token;
    await _sendTokenToBackend(token);
  }

  /// После успешного входа (если bootstrap ещё не успел зарегистрировать токен).
  Future<void> registerTokenAfterLogin() async {
    if (_fcmToken != null) {
      await _sendTokenToBackend(_fcmToken);
      return;
    }
    try {
      final t = await FirebaseMessaging.instance.getToken();
      _fcmToken = t;
      await _sendTokenToBackend(t);
    } catch (_) {}
  }

  /// Перед полной очисткой сессии (пока JWT ещё в Hive).
  Future<void> unregisterTokenOnLogout() async {
    final token = _fcmToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    final authBox = Hive.box('authBox');
    final jwt = authBox.get('token') as String?;
    if (jwt == null || jwt.isEmpty) return;
    try {
      await ApiClient.instance.delete(
        '/users/me/push-token',
        withAuth: true,
        body: {'token': token},
      );
    } catch (_) {}
  }

  Future<void> _initLocalNotifications() async {
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChatChannel);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          _handleOpenFromData(map);
        } catch (_) {}
      },
    );
  }

  Future<void> _sendTokenToBackend(String? token) async {
    if (token == null || token.isEmpty) return;
    final authBox = Hive.box('authBox');
    final jwt = authBox.get('token') as String?;
    if (jwt == null || jwt.isEmpty) return;
    try {
      await ApiClient.instance.post(
        '/users/me/push-token',
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
        withAuth: true,
      );
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString();
    if (type == 'direct') {
      final peerId = data['peer_id']?.toString();
      if (peerId != null &&
          ChatPresenceTracker.instance.shouldSuppressDirect(peerId)) {
        return;
      }
    } else if (type == 'event') {
      final eventId = data['event_id']?.toString();
      if (eventId != null &&
          ChatPresenceTracker.instance.shouldSuppressEvent(eventId)) {
        return;
      }
    }

    final n = message.notification;
    final title = n?.title ?? 'Сообщение';
    final body = n?.body ?? '';

    final payload = jsonEncode(data);
    final id = Object.hash(
      data['peer_id'] ?? data['event_id'] ?? '',
      DateTime.now().millisecondsSinceEpoch,
    ).abs();

    _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChatChannel.id,
          _androidChatChannel.name,
          channelDescription: _androidChatChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
