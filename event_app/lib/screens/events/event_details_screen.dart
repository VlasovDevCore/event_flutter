import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/event_marker_catalog.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';
import '../../widgets/event_marker_widget.dart';
import '../chat/event_chat_screen.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  final Event event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Event? _event;
  bool _loading = true;
  bool _savingEdit = false;
  String? _error;

  // Привязка к стилю приложения (темная палитра).
  static const Color _bg = Color(0xFF161616);
  static const Color _appBarBg = Color(0xCC161616);
  static const Color _cardBg = Color(0xFF1C1F26);
  static const Color _cardBorder = Color(0xFF23262C);
  static const Color _text = Color(0xFFDFE3EC);
  static const Color _subtitle = Color(0xFFB5BBC7);
  static const Color _muted = Color(0xFFAAABB0);
  static const Color _danger = Color(0xFFFF5F57);
  static const Color _goingBg = Color(0xFFFF8A8A);
  static const Color _notGoingBg = Color(0xFF36D3F0);
  static const Color _secondaryBtnBg = Color(0xFF151922);

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
        myEmail != null && creatorEmail != null && myEmail.toLowerCase() == creatorEmail;
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

  Future<void> _openEditSheet(Event event) async {
    final titleController = TextEditingController(text: event.title);
    final descriptionController = TextEditingController(text: event.description);

    Color selectedColor = Color(event.markerColorValue);
    final colorAllowed = EventMarkerCatalog.availableColors.any(
      (c) => c.toARGB32() == selectedColor.toARGB32(),
    );
    if (!colorAllowed) {
      selectedColor = EventMarkerCatalog.availableColors.first;
    }

    final userStatus = (Hive.box('authBox').get('status') as int?) ?? 1;
    var icons = EventMarkerCatalog.availableIconsForUserStatus(userStatus);
    if (icons.isEmpty) {
      icons = EventMarkerCatalog.availableIconsForUserStatus(1);
    }
    IconData selectedIcon = IconData(
      event.markerIconCodePoint,
      fontFamily: 'MaterialIcons',
    );
    final iconAllowed = icons.any((i) => i.codePoint == selectedIcon.codePoint);
    if (!iconAllowed) {
      selectedIcon = icons.first;
    }

    final result = await showModalBottomSheet<_EditEventPayload>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: false,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                        children: [
                          EventMarkerWidget(
                            color: selectedColor,
                            icon: selectedIcon,
                            size: 40,
                            iconSize: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Редактирование события',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Название',
                          filled: true,
                          fillColor: const Color(0xFF141414),
                          labelStyle: const TextStyle(color: _subtitle),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _notGoingBg.withOpacity(0.9), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Описание',
                          filled: true,
                          fillColor: const Color(0xFF141414),
                          labelStyle: const TextStyle(color: _subtitle),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _notGoingBg.withOpacity(0.9), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Цвет',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EventMarkerCatalog.availableColors.map((c) {
                          final selected = c.toARGB32() == selectedColor.toARGB32();
                          return InkWell(
                            onTap: () => setSheetState(() => selectedColor = c),
                            borderRadius: BorderRadius.circular(999),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: c,
                              child: selected
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Иконка',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: icons.map((i) {
                          final selected = i.codePoint == selectedIcon.codePoint;
                          return InkWell(
                            onTap: () => setSheetState(() => selectedIcon = i),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(i),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _notGoingBg,
                            foregroundColor: const Color(0xFF021018),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Введите название')),
                              );
                              return;
                            }

                            Navigator.of(context).pop(
                              _EditEventPayload(
                                title: title,
                                description: descriptionController.text.trim(),
                                markerColorValue: selectedColor.toARGB32(),
                                markerIconCodePoint: selectedIcon.codePoint,
                              ),
                            );
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Сохранить'),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (result == null || !mounted) return;
    await _saveEventEdit(event, result);
  }

  Future<void> _saveEventEdit(Event base, _EditEventPayload edit) async {
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
                goingUsers: parsed.goingUsers.isNotEmpty ? parsed.goingUsers : base.goingUsers,
                notGoingUsers:
                    parsed.notGoingUsers.isNotEmpty ? parsed.notGoingUsers : base.notGoingUsers,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Событие обновлено')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingEdit = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingEdit = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления: $e')),
      );
    }
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.instance;
      final data = await client.get('/events/${widget.event.id}', withAuth: true);
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
          const SnackBar(content: Text('Войдите в аккаунт, чтобы отметить участие')),
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
            .map((e) => EventUserProfile.fromApiMap(Map<String, dynamic>.from(e as Map)))
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
          // Если API не вернул профили участников (например, только email/ids),
          // сохраняем старые, чтобы UI создателя/аватаров не "мигал".
          goingUserProfiles: goingProfiles.isNotEmpty ? goingProfiles : base.goingUserProfiles,
          notGoingUserProfiles: notGoingProfiles.isNotEmpty ? notGoingProfiles : base.notGoingUserProfiles,
          endsAt: base.endsAt,
          creatorId: base.creatorId,
          creatorEmail: base.creatorEmail,
          creatorName: base.creatorName,
        );
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.statusCode == 401 ? 'Войдите в аккаунт' : e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final event = _event ?? widget.event;
    final me = _currentUserEmail();
    final goingSelected = me != null && event.goingUsers.contains(me);
    final goingCount = event.goingUsers.length;

    // Ищем профиль создателя среди полученных профилей участников.
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
            : (event.creatorName?.isNotEmpty == true ? event.creatorName! : 'Пользователь');
    final creatorNickname =
        (creatorProfile?.username?.isNotEmpty == true) ? '@${creatorProfile!.username}' : '—';
    final creatorResolvedAvatar = resolveAvatarUrl(creatorProfile?.avatarUrl);
    const creatorPlaceholderBg = Color(0xFF2A2E37);

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
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBg.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Создано: ${dateFormat.format(event.createdAt)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: _subtitle,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _cardBorder, width: 1),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: creatorPlaceholderBg,
                          backgroundImage: creatorResolvedAvatar != null
                              ? NetworkImage(creatorResolvedAvatar)
                              : null,
                          child: creatorResolvedAvatar != null
                              ? null
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                        title: Text(
                          creatorTitle,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          creatorNickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: _subtitle,
                            fontSize: 12,
                          ),
                        ),
                        onTap: (creatorId != null && creatorId.isNotEmpty)
                            ? () => _openProfileById(creatorId)
                            : null,
                      ),
                    ),
                    if (event.endsAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Актуально до: ${DateFormat('dd.MM.yyyy HH:mm').format(event.endsAt!)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _subtitle,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
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
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: goingSelected ? _goingBg : _notGoingBg,
                              foregroundColor: const Color(0xFF021018),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: () => _setRsvp(goingSelected ? -1 : 1),
                            icon: Icon(
                              goingSelected ? Icons.close : Icons.check,
                              color: const Color(0xFF021018),
                            ),
                            label: Text(
                              goingSelected ? 'Не приду' : 'Я приду',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (event.goingUsers.isNotEmpty) ...[
                      Text(
                        'Кто придёт:',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(event.goingUserProfiles.isNotEmpty
                          ? event.goingUserProfiles.map((u) {
                              final title = (u.displayName?.isNotEmpty == true)
                                  ? u.displayName!
                                  : (u.username?.isNotEmpty == true
                                      ? u.username!
                                      : 'Пользователь');
                              final subtitle =
                                  (u.username?.isNotEmpty == true) ? '@${u.username}' : '—';
                              final resolvedAvatar = resolveAvatarUrl(u.avatarUrl);
                              const listPlaceholderBg = Color(0xFF2A2E37);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _cardBorder, width: 1),
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: listPlaceholderBg,
                                    backgroundImage:
                                        resolvedAvatar != null ? NetworkImage(resolvedAvatar) : null,
                                    child: resolvedAvatar != null
                                        ? null
                                        : const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: subtitle == null
                                      ? null
                                      : Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            color: _subtitle,
                                            fontSize: 12,
                                          ),
                                        ),
                                  onTap: u.id.isEmpty
                                      ? null
                                      : () => _openProfileById(u.id),
                                ),
                              );
                            })
                          : event.goingUsers.map((name) {
                              final raw = name.trim();
                              final isMe = me != null && raw == me;
                              final hasAt = raw.contains('@');
                              final localPart =
                                  hasAt ? raw.split('@').first.trim() : raw;
                              final displayName = localPart.isNotEmpty ? localPart : 'Пользователь';
                              final nickname =
                                  hasAt && localPart.isNotEmpty ? '@$localPart' : '—';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _cardBorder, width: 1),
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: const Icon(Icons.person, color: Colors.white),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isMe ? 'Это вы' : nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: _subtitle,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            })),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        'Пока никто не отметил “Я приду”',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _subtitle,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (event.description.isNotEmpty)
                      Text(
                        event.description,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _subtitle,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        'Описание не указано',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: _subtitle,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Координаты:',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Широта: ${event.lat.toStringAsFixed(5)}\nДолгота: ${event.lon.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: _subtitle,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _secondaryBtnBg,
                          foregroundColor: _text,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EventChatScreen(event: event),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, color: _text),
                        label: const Text(
                          'Открыть чат события',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EditEventPayload {
  const _EditEventPayload({
    required this.title,
    required this.description,
    required this.markerColorValue,
    required this.markerIconCodePoint,
  });

  final String title;
  final String description;
  final int markerColorValue;
  final int markerIconCodePoint;
}

