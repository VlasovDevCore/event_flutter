import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../../config/event_marker_catalog.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';
import '../chat/event_chat_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/detail/detail_chat_button.dart';
import '../../widgets/detail/detail_description.dart';
import '../../widgets/detail/detail_edit_payload.dart';
import '../../widgets/detail/detail_edit_sheet.dart';
import '../../widgets/detail/detail_event_header.dart';
import '../../widgets/detail/detail_creator_card.dart';
import '../../widgets/detail/detail_attendees_section.dart';
import '../../widgets/detail/detail_rsvp_section.dart';

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

  Future<void> _openYandexMaps() async {
    final event = _event ?? widget.event;
    final lat = event.lat;
    final lon = event.lon;

    final url = Uri.parse('https://yandex.ru/maps/?pt=$lon,$lat&z=17&l=map');

    try {
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
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: DetailEditSheet(
            initialTitle: event.title,
            initialDescription: event.description,
            initialImageUrl: event.imageUrl,
            initialColor: selectedColor,
            initialIcon: selectedIcon,
            onSave: (payload) => Navigator.of(context).pop(payload),
          ),
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

      Event updated = data.isNotEmpty
          ? (() {
              final parsed = Event.fromApiMap(data);
              return Event(
                id: parsed.id,
                title: parsed.title,
                description: parsed.description,
                imageUrl: parsed.imageUrl ?? base.imageUrl,
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
              imageUrl: base.imageUrl,
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

      // Handle image actions after metadata save:
      if (edit.removeImage) {
        await ApiClient.instance.delete(
          '/events/${base.id}/image',
          withAuth: true,
        );
        updated = Event(
          id: updated.id,
          title: updated.title,
          description: updated.description,
          imageUrl: null,
          lat: updated.lat,
          lon: updated.lon,
          createdAt: updated.createdAt,
          markerColorValue: updated.markerColorValue,
          markerIconCodePoint: updated.markerIconCodePoint,
          rsvpStatus: updated.rsvpStatus,
          goingUsers: updated.goingUsers,
          notGoingUsers: updated.notGoingUsers,
          goingUserProfiles: updated.goingUserProfiles,
          notGoingUserProfiles: updated.notGoingUserProfiles,
          endsAt: updated.endsAt,
          creatorId: updated.creatorId,
          creatorEmail: updated.creatorEmail,
          creatorName: updated.creatorName,
        );
      } else if (edit.localImagePath != null &&
          edit.localImagePath!.trim().isNotEmpty) {
        final file = File(edit.localImagePath!);
        final bytes = await file.readAsBytes();
        final filename = edit.localImagePath!.split(Platform.pathSeparator).last;
        final upload = await ApiClient.instance.uploadImage(
          '/events/${base.id}/image',
          bytes: bytes,
          filename: filename.isEmpty ? 'event.jpg' : filename,
          fieldName: 'image',
          withAuth: true,
        );
        final imageUrl = upload['image_url']?.toString();
        updated = Event(
          id: updated.id,
          title: updated.title,
          description: updated.description,
          imageUrl: (imageUrl != null && imageUrl.trim().isNotEmpty)
              ? imageUrl.trim()
              : updated.imageUrl,
          lat: updated.lat,
          lon: updated.lon,
          createdAt: updated.createdAt,
          markerColorValue: updated.markerColorValue,
          markerIconCodePoint: updated.markerIconCodePoint,
          rsvpStatus: updated.rsvpStatus,
          goingUsers: updated.goingUsers,
          notGoingUsers: updated.notGoingUsers,
          goingUserProfiles: updated.goingUserProfiles,
          notGoingUserProfiles: updated.notGoingUserProfiles,
          endsAt: updated.endsAt,
          creatorId: updated.creatorId,
          creatorEmail: updated.creatorEmail,
          creatorName: updated.creatorName,
        );
      }

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
          imageUrl: base.imageUrl,
          lat: base.lat,
          lon: base.lon,
          createdAt: base.createdAt,
          markerColorValue: base.markerColorValue,
          markerIconCodePoint: base.markerIconCodePoint,
          rsvpStatus: status,
          goingUsers: going,
          notGoingUsers: notGoing,
          goingUserProfiles: goingProfiles,
          notGoingUserProfiles: notGoingProfiles,
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
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          SafeArea(
            top: true,
            bottom: true,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : CustomScrollView(
                    slivers: [
                      // Кастомный заголовок
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              _buildBackButton(context),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Подробности',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (_isCreator(event)) _buildEditButton(event),
                            ],
                          ),
                        ),
                      ),
                      // Контент
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
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
                            if ((ApiClient.getFullImageUrl(event.imageUrl) ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 200,
                                  child: Image.network(
                                    ApiClient.getFullImageUrl(event.imageUrl)!,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 200,
                                      color: const Color(0xFF141414),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Заголовок и даты
                            DetailEventHeader(
                              title: event.title,
                              createdAt: event.createdAt,
                              endsAt: event.endsAt,
                            ),
                            const SizedBox(height: 16),
                            // Карточка создателя
                            DetailCreatorCard(
                              creatorId: creatorId,
                              creatorTitle: creatorTitle,
                              creatorNickname: creatorNickname,
                              creatorAvatarUrl: creatorResolvedAvatar,
                              onTap: (creatorId != null && creatorId.isNotEmpty)
                                  ? () => _openProfileById(creatorId)
                                  : null,
                            ),
                            const SizedBox(height: 26),
                            // Секция участников
                            DetailAttendeesSection(
                              event: event,
                              currentUserEmail: me,
                              onProfileTap: _openProfileById,
                            ),
                            const SizedBox(height: 10),
                            // Кнопки RSVP
                            DetailRsvpSection(
                              isGoing: goingSelected,
                              onPressed: () => _setRsvp(goingSelected ? -1 : 1),
                            ),
                            const SizedBox(height: 10),
                            // Описание
                            DetailDescription(description: event.description),
                            const SizedBox(height: 20),
                            // Кнопки чата и карты
                            _buildActionButtons(event),
                            const SizedBox(height: 24),
                          ]),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 0.55,
            colors: [
              const Color.fromARGB(197, 29, 29, 29),
              const Color(0xFF161616),
            ],
            stops: const [0.1, 4.9],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
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
            onTap: () => Navigator.of(context).pop(),
            splashColor: const Color.fromARGB(157, 0, 0, 0),
            highlightColor: const Color.fromARGB(157, 0, 0, 0),
            child: const Center(
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton(Event event) {
    return Container(
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
          onTap: _savingEdit ? null : () => _openEditSheet(event),
          splashColor: const Color.fromARGB(157, 0, 0, 0),
          highlightColor: const Color.fromARGB(157, 0, 0, 0),
          child: Center(
            child: _savingEdit
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Event event) {
    return Row(
      children: [
        Expanded(
          child: DetailChatButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EventChatScreen(event: event),
                ),
              );
            },
            onMapPressed: _openYandexMaps,
          ),
        ),
      ],
    );
  }

  String? _resolveAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl;
    }
    if (avatarUrl.startsWith('/uploads')) {
      return '${ApiClient.baseUrl}$avatarUrl';
    }
    if (avatarUrl.startsWith('file://')) {
      return avatarUrl;
    }
    return null;
  }
}
