import 'dart:async';
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
import 'widgets/report_event_sheet.dart';
import '../auth/verify_email_code_screen.dart';

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
  bool _accessLocked = false;
  int _blacklistCount = 0;

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
  bool get _isEmailVerified =>
      ((Hive.box('authBox').get('status') as int?) ?? 1) != 0;

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

  Future<void> _blacklistUserFromEvent(String userId) async {
    try {
      await ApiClient.instance.post(
        '/events/${widget.event.id}/blacklist',
        withAuth: true,
        body: {'userId': userId},
      );
      if (!mounted) return;
      setState(() => _blacklistCount += 1);
      await _loadEvent();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь удалён')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _showEventBlacklist() async {
    if (!_isLoggedIn) return;
    final event = _event ?? widget.event;
    if (!_isCreator(event)) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: ApiClient.instance.get(
                '/events/${widget.event.id}/blacklist',
                withAuth: true,
              ),
              builder: (context, snapshot) {
                final usersRaw = snapshot.data?['users'];
                final users = usersRaw is List ? usersRaw : const [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.block, color: Colors.white70),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Чёрный список (${users.length})',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: (snapshot.connectionState != ConnectionState.done)
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : (users.isEmpty
                              ? const SizedBox.shrink()
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  itemCount: users.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final u = users[index];
                                    if (u is! Map) return const SizedBox.shrink();
                                    final map = Map<String, dynamic>.from(u);
                                    final id = map['id']?.toString() ?? '';
                                    final avatarUrl =
                                        (map['avatar_url'] ?? map['avatarUrl'])
                                            ?.toString();
                                    final displayName =
                                        (map['display_name'] ?? map['displayName'])
                                            ?.toString()
                                            .trim();
                                    final username = map['username']?.toString().trim();
                                    final email = map['email']?.toString().trim();
                                    final title = (displayName != null && displayName.isNotEmpty)
                                        ? displayName
                                        : (username != null && username.isNotEmpty)
                                            ? '@$username'
                                            : (email ?? 'Пользователь');
                                    final subtitle = (username != null && username.isNotEmpty)
                                        ? '@$username'
                                        : (email ?? '—');

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF141414),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: (() {
                                            if (avatarUrl == null ||
                                                avatarUrl.trim().isEmpty) {
                                              return Container(
                                                width: 44,
                                                height: 44,
                                                color: const Color(0xFF2A2A2A),
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.white54,
                                                  size: 22,
                                                ),
                                              );
                                            }
                                            final resolved =
                                                _resolveAvatarUrl(avatarUrl);
                                            if (resolved == null ||
                                                resolved.trim().isEmpty) {
                                              return Container(
                                                width: 44,
                                                height: 44,
                                                color: const Color(0xFF2A2A2A),
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.white54,
                                                  size: 22,
                                                ),
                                              );
                                            }
                                            return Image.network(
                                              resolved,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                width: 44,
                                                height: 44,
                                                color: const Color(0xFF2A2A2A),
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.white54,
                                                  size: 22,
                                                ),
                                              ),
                                            );
                                          })(),
                                        ),
                                        title: Text(
                                          title,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFFAAABB0),
                                          ),
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Убрать из чёрного списка',
                                          onPressed: id.trim().isEmpty
                                              ? null
                                              : () async {
                                                  try {
                                                    await ApiClient.instance.delete(
                                                      '/events/${widget.event.id}/blacklist/$id',
                                                      withAuth: true,
                                                    );
                                                    if (!mounted) return;
                                                    setState(() {
                                                      _blacklistCount =
                                                          (_blacklistCount - 1).clamp(
                                                        0,
                                                        1 << 30,
                                                      );
                                                    });
                                                    Navigator.pop(context);
                                                    await _loadEvent();
                                                  } catch (_) {}
                                                },
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Color(0xFFFF5F57),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _refreshBlacklistCount() async {
    if (!_isLoggedIn) return;
    final event = _event ?? widget.event;
    if (!_isCreator(event)) return;
    try {
      final data = await ApiClient.instance.get(
        '/events/${widget.event.id}/blacklist/count',
        withAuth: true,
      );
      final raw = data['count'];
      final n = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (!mounted) return;
      setState(() => _blacklistCount = n < 0 ? 0 : n);
    } catch (_) {}
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
      _accessLocked = false;
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
      // подтянем счётчик ЧС (если я организатор)
      unawaited(_refreshBlacklistCount());
    } catch (e) {
      final api = e is ApiException ? e : null;
      setState(() {
        _accessLocked =
            api != null && (api.statusCode == 403 || api.statusCode == 404);
        _error = api != null ? api.message : e.toString();
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

    if (_isLoggedIn && !_isEmailVerified) {
      return Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            _buildBackgroundGradient(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/avatar/at-dynamic-color.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Ваш email не подтверждён',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Чтобы продолжить, подтвердите почту кодом из письма.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.35,
                          color: Color(0xFFAAABB0),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await Navigator.of(context).push<bool>(
                              MaterialPageRoute<bool>(
                                builder: (_) => const VerifyEmailCodeScreen(),
                              ),
                            );
                            if (ok == true && mounted) {
                              setState(() {});
                            }
                          },
                          child: const Text(
                            'Подтвердить email',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF222222)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Закрыть'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                : (_accessLocked
                    ? Stack(
                        children: [
                          Positioned(
                            top: 8,
                            right: 12,
                            child: SafeArea(
                              bottom: false,
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
                                    splashColor:
                                        const Color.fromARGB(157, 0, 0, 0),
                                    highlightColor:
                                        const Color.fromARGB(157, 0, 0, 0),
                                    child: const Center(
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/friends/lock-dynamic-color.png',
                                    width: 120,
                                    height: 120,
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Доступ к событию закрыт',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Вы не можете просматривать это событие.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      height: 1.35,
                                      color: Color(0xFFAAABB0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                              if (_isLoggedIn && !_isCreator(event)) ...[
                                _buildReportButton(event),
                                const SizedBox(width: 10),
                              ],
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
                              canManageBlacklist: _isCreator(event) && _isLoggedIn,
                              onBlacklistUser: _blacklistUserFromEvent,
                            ),
                            if (_isCreator(event) && _isLoggedIn && _blacklistCount > 0) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2A2A2A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _showEventBlacklist,
                                  child: Text(
                                    'Чёрный список участников ($_blacklistCount)',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                  )),
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

  Widget _buildReportButton(Event event) {
    return Tooltip(
      message: 'Пожаловаться',
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
            onTap: () {
              showReportEventSheet(
                context,
                eventId: event.id,
                eventTitle: event.title,
              );
            },
            splashColor: const Color.fromARGB(157, 0, 0, 0),
            highlightColor: const Color.fromARGB(157, 0, 0, 0),
            child: const Center(
              child: Icon(
                Icons.flag_outlined,
                color: Color(0xFFFF5F57),
                size: 18,
              ),
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
