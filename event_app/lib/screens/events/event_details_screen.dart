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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Название',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Цвет', style: Theme.of(context).textTheme.titleSmall),
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
                      Text('Иконка', style: Theme.of(context).textTheme.titleSmall),
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
          goingUserProfiles: goingProfiles,
          notGoingUserProfiles: notGoingProfiles,
          endsAt: base.endsAt,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подробности события'),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создано: ${dateFormat.format(event.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Создатель: ${_creatorLabel(event)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.endsAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Актуально до: ${DateFormat('dd.MM.yyyy HH:mm').format(event.endsAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Придут: $goingCount',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _setRsvp(goingSelected ? -1 : 1),
                          icon: Icon(goingSelected ? Icons.close : Icons.check),
                          label: Text(goingSelected ? 'Не приду' : 'Я приду'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (event.goingUsers.isNotEmpty) ...[
                    Text(
                      'Кто придёт:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...(event.goingUserProfiles.isNotEmpty
                        ? event.goingUserProfiles.map((u) {
                            final title = (u.displayName?.isNotEmpty == true)
                                ? u.displayName!
                                : (u.username?.isNotEmpty == true
                                    ? '@${u.username}'
                                    : (u.email ?? '—'));
                            final subtitle = u.username?.isNotEmpty == true ? u.email : null;
                            final resolvedAvatar = resolveAvatarUrl(u.avatarUrl);
                            final bgColor = u.avatarColorValue != null
                                ? Color(u.avatarColorValue!)
                                : const Color(0xFF2A2E37);
                            final iconPoint = u.avatarIconCode ?? Icons.person.codePoint;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: bgColor,
                                backgroundImage:
                                    resolvedAvatar != null ? NetworkImage(resolvedAvatar) : null,
                                child: resolvedAvatar != null
                                    ? null
                                    : Icon(
                                        IconData(iconPoint, fontFamily: 'MaterialIcons'),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                              title: Text(title),
                              subtitle: subtitle == null
                                  ? null
                                  : Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: u.id.isEmpty
                                  ? null
                                  : () {
                                      final rawMyId = Hive.box('authBox').get('userId');
                                      final myId = rawMyId?.toString();
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => (myId != null && myId == u.id)
                                              ? const ProfileScreen()
                                              : ProfileScreen(userId: u.id),
                                        ),
                                      );
                                    },
                            );
                          })
                        : event.goingUsers.map(
                            (name) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.person),
                              title: Text(name),
                              subtitle: me == name ? const Text('Это вы') : null,
                            ),
                          )),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Пока никто не отметил “Я приду”',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (event.description.isNotEmpty)
                    Text(
                      event.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    Text(
                      'Описание не указано',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Координаты:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Широта: ${event.lat.toStringAsFixed(5)}\nДолгота: ${event.lon.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EventChatScreen(event: event),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Открыть чат события'),
                    ),
                  ),
                ],
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

