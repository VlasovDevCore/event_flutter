import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/event_marker_catalog.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';
import '../chat/event_chat_screen.dart';
// import '../profile/profile_avatar.dart';
import '../profile/profile_screen.dart';
import '../../widgets/detail/detail_attendees_list.dart';
import '../../widgets/detail/detail_chat_button.dart';
import '../../widgets/detail/detail_coordinates.dart';
import '../../widgets/detail/detail_creator_card.dart';
import '../../widgets/detail/detail_description.dart';
import '../../widgets/detail/detail_edit_payload.dart';
import '../../widgets/detail/detail_edit_sheet.dart';
import '../../widgets/detail/detail_event_header.dart';
import '../../widgets/detail/detail_rsvp_button.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Event? _event;
  bool _loading = true;
  bool _savingEdit = false;
  String? _error;

  static const Color _bg = Color(0xFF161616);
  static const Color _appBarBg = Color(0xCC161616);
  static const Color _text = Color(0xFFDFE3EC);

  void _openProfileById(String userId) {
    final rawMyId = Hive.box('authBox').get('userId');
    final myId = rawMyId?.toString();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => (myId != null && myId == userId)
            ? const ProfileScreen()
            : ProfileScreen(userId: userId),
      ),
    );
  }

  String? _currentUserEmail() {
    final authBox = Hive.box('authBox');
    final email = authBox.get('email') as String?;
    if (email == null || email.trim().isEmpty) return null;
    return email.trim();
  }

  bool get _isLoggedIn => Hive.box('authBox').get('token') != null;

  String? _currentUserId() {
    final authBox = Hive.box('authBox');
    final raw = authBox.get('userId');
    if (raw == null) return null;
    final userId = raw.toString().trim();
    if (userId.isEmpty) return null;
    return userId;
  }

  bool _isCreator(Event event) {
    final myId = _currentUserId();
    final myEmail = _currentUserEmail();
    final creatorId = event.creatorId?.trim();
    final creatorEmail = event.creatorEmail?.trim().toLowerCase();

    final byId = myId != null && creatorId != null && myId == creatorId;
    final byEmail =
        myEmail != null &&
        creatorEmail != null &&
        myEmail.toLowerCase() == creatorEmail;
    return byId || byEmail;
  }

  String _creatorLabel(Event event) {
    if (event.creatorName != null && event.creatorName!.trim().isNotEmpty) {
      return event.creatorName!.trim();
    }
    if (event.creatorEmail != null && event.creatorEmail!.trim().isNotEmpty) {
      return event.creatorEmail!.trim();
    }
    if (event.creatorId != null && event.creatorId!.trim().isNotEmpty) {
      return 'id: ${event.creatorId!.trim()}';
    }
    return 'не указан';
  }

  Future<void> _openYandexMaps() async {
    final event = _event ?? widget.event;
    final lat = event.lat;
    final lon = event.lon;

    // Яндекс.Карты в веб-версии
    final url = Uri.parse('https://yandex.ru/maps/?pt=$lon,$lat&z=17&l=map');

    try {
      // Открываем в системном браузере
      await launchUrl(url, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть карты')),
        );
      }
    }
  }

  Future<void> _openEditSheet(Event event) async {
    Color selectedColor = Color(event.markerColorValue);
    final colorAllowed = EventMarkerCatalog.availableColors.any(
      (c) => c.toARGB32() == selectedColor.toARGB32(),
    );
    if (!colorAllowed) {
      selectedColor = EventMarkerCatalog.availableColors.first;
    }

    IconData selectedIcon = IconData(
      event.markerIconCodePoint,
      fontFamily: 'MaterialIcons',
    );

    final result = await showModalBottomSheet<DetailEditPayload>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: false,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DetailEditSheet(
          initialTitle: event.title,
          initialDescription: event.description,
          initialColor: selectedColor,
          initialIcon: selectedIcon,
          onSave: (payload) => Navigator.of(context).pop(payload),
        );
      },
    );

    if (result == null || !mounted) return;
    await _saveEventEdit(event, result);
  }

  Future<void> _saveEventEdit(Event base, DetailEditPayload edit) async {
    setState(() {
      _savingEdit = true;
    });
    try {
      final data = await ApiClient.instance.put(
        '/events/${base.id}',
        withAuth: true,
        body: {
          'title': edit.title,
          'description': edit.description,
          'markerColorValue': edit.markerColorValue,
          'markerIconCode': edit.markerIconCodePoint,
        },
      );

      final updated = data.isNotEmpty
          ? (() {
              final parsed = Event.fromApiMap(data);
              return Event(
                id: parsed.id,
                title: parsed.title,
                description: parsed.description,
                lat: parsed.lat,
                lon: parsed.lon,
                createdAt: parsed.createdAt,
                markerColorValue: parsed.markerColorValue,
                markerIconCodePoint: parsed.markerIconCodePoint,
                rsvpStatus: parsed.rsvpStatus,
                goingUsers: parsed.goingUsers.isNotEmpty
                    ? parsed.goingUsers
                    : base.goingUsers,
                notGoingUsers: parsed.notGoingUsers.isNotEmpty
                    ? parsed.notGoingUsers
                    : base.notGoingUsers,
                goingUserProfiles: parsed.goingUserProfiles.isNotEmpty
                    ? parsed.goingUserProfiles
                    : base.goingUserProfiles,
                notGoingUserProfiles: parsed.notGoingUserProfiles.isNotEmpty
                    ? parsed.notGoingUserProfiles
                    : base.notGoingUserProfiles,
                endsAt: parsed.endsAt ?? base.endsAt,
                creatorId: parsed.creatorId ?? base.creatorId,
                creatorEmail: parsed.creatorEmail ?? base.creatorEmail,
                creatorName: parsed.creatorName ?? base.creatorName,
              );
            })()
          : Event(
              id: base.id,
              title: edit.title,
              description: edit.description,
              lat: base.lat,
              lon: base.lon,
              createdAt: base.createdAt,
              markerColorValue: edit.markerColorValue,
              markerIconCodePoint: edit.markerIconCodePoint,
              rsvpStatus: base.rsvpStatus,
              goingUsers: base.goingUsers,
              notGoingUsers: base.notGoingUsers,
              goingUserProfiles: base.goingUserProfiles,
              notGoingUserProfiles: base.notGoingUserProfiles,
              endsAt: base.endsAt,
              creatorId: base.creatorId,
              creatorEmail: base.creatorEmail,
              creatorName: base.creatorName,
            );

      if (!mounted) return;
      setState(() {
        _event = updated;
        _savingEdit = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Событие обновлено')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingEdit = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingEdit = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e')));
    }
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.instance;
      final data = await client.get(
        '/events/${widget.event.id}',
        withAuth: true,
      );
      setState(() {
        _event = Event.fromApiMap(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _event = null;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _setRsvp(int status) async {
    if (!_isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Войдите в аккаунт, чтобы отметить участие'),
          ),
        );
      }
      return;
    }

    try {
      final client = ApiClient.instance;
      final data = await client.post(
        '/events/${widget.event.id}/rsvp',
        body: {'status': status},
        withAuth: true,
      );

      List<EventUserProfile> parseProfiles(List raw) {
        return raw
            .where((e) => e is Map)
            .map(
              (e) => EventUserProfile.fromApiMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }

      List<String> parseEmails(List raw) {
        return raw.map((e) {
          if (e is String) return e;
          if (e is Map && e['email'] != null) return e['email'].toString();
          return e.toString();
        }).toList();
      }

      final goingRaw = (data['going_users'] as List?) ?? const [];
      final notGoingRaw = (data['not_going_users'] as List?) ?? const [];

      final going = parseEmails(goingRaw);
      final notGoing = parseEmails(notGoingRaw);
      final goingProfiles = parseProfiles(goingRaw);
      final notGoingProfiles = parseProfiles(notGoingRaw);
      setState(() {
        final base = _event ?? widget.event;
        _event = Event(
          id: base.id,
          title: base.title,
          description: base.description,
          lat: base.lat,
          lon: base.lon,
          createdAt: base.createdAt,
          markerColorValue: base.markerColorValue,
          markerIconCodePoint: base.markerIconCodePoint,
          rsvpStatus: status,
          goingUsers: going,
          notGoingUsers: notGoing,
          goingUserProfiles: goingProfiles.isNotEmpty
              ? goingProfiles
              : base.goingUserProfiles,
          notGoingUserProfiles: notGoingProfiles.isNotEmpty
              ? notGoingProfiles
              : base.notGoingUserProfiles,
          endsAt: base.endsAt,
          creatorId: base.creatorId,
          creatorEmail: base.creatorEmail,
          creatorName: base.creatorName,
        );
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.statusCode == 401 ? 'Войдите в аккаунт' : e.message,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event ?? widget.event;
    final me = _currentUserEmail();
    final goingSelected = me != null && event.goingUsers.contains(me);
    final goingCount = event.goingUsers.length;

    // Ищем профиль создателя
    final creatorProfiles = <EventUserProfile>[
      ...event.goingUserProfiles,
      ...event.notGoingUserProfiles,
    ];
    final creatorId = event.creatorId;
    final creatorEmail = event.creatorEmail;
    EventUserProfile? creatorProfile;
    for (final p in creatorProfiles) {
      if (creatorId != null && creatorId.isNotEmpty && p.id == creatorId) {
        creatorProfile = p;
        break;
      }
      if (creatorProfile == null &&
          creatorEmail != null &&
          creatorEmail.isNotEmpty &&
          p.email != null &&
          p.email == creatorEmail) {
        creatorProfile = p;
        break;
      }
    }

    final creatorTitle = (creatorProfile?.displayName?.isNotEmpty == true)
        ? creatorProfile!.displayName!
        : (creatorProfile?.username?.isNotEmpty == true)
        ? creatorProfile!.username!
        : (event.creatorName?.isNotEmpty == true
              ? event.creatorName!
              : 'Пользователь');
    final creatorNickname = (creatorProfile?.username?.isNotEmpty == true)
        ? '@${creatorProfile!.username}'
        : '—';
    final creatorResolvedAvatar = _resolveAvatarUrl(creatorProfile?.avatarUrl);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBarBg,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Подробности события',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isCreator(event))
            IconButton(
              onPressed: _savingEdit ? null : () => _openEditSheet(event),
              icon: _savingEdit
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined),
              tooltip: 'Редактировать',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFFFF5F57),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  DetailEventHeader(
                    title: event.title,
                    createdAt: event.createdAt,
                    endsAt: event.endsAt,
                  ),
                  const SizedBox(height: 8),
                  DetailCreatorCard(
                    creatorId: creatorId,
                    creatorTitle: creatorTitle,
                    creatorNickname: creatorNickname,
                    creatorAvatarUrl: creatorResolvedAvatar,
                    onTap: (creatorId != null && creatorId.isNotEmpty)
                        ? () => _openProfileById(creatorId)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Придут: $goingCount',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: _text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DetailRsvpButton(
                        isGoing: goingSelected,
                        onPressed: () => _setRsvp(goingSelected ? -1 : 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DetailAttendeesList(
                    goingUsers: event.goingUsers,
                    goingUserProfiles: event.goingUserProfiles,
                    currentUserEmail: me,
                    onProfileTap: _openProfileById,
                  ),
                  const SizedBox(height: 16),
                  DetailDescription(description: event.description),
                  // const SizedBox(height: 24),
                  // DetailCoordinates(lat: event.lat, lon: event.lon),
                  const SizedBox(height: 20),
                  DetailChatButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EventChatScreen(event: event),
                        ),
                      );
                    },
                    onMapPressed: _openYandexMaps, // Добавьте эту строку
                  ),
                ],
              ),
            ),
    );
  }

  String? _resolveAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;

    // Если URL уже полный (http/https)
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl;
    }

    // Если путь начинается с /uploads, добавляем базовый URL из ApiClient
    if (avatarUrl.startsWith('/uploads')) {
      return '${ApiClient.baseUrl}$avatarUrl';
    }

    // Если путь начинается с file://, это локальный файл
    if (avatarUrl.startsWith('file://')) {
      return avatarUrl;
    }

    return null;
  }
}
