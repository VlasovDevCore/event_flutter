import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../services/api_client.dart';
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
  String? _error;

  String? _currentUserEmail() {
    final authBox = Hive.box('authBox');
    final email = authBox.get('email') as String?;
    if (email == null || email.trim().isEmpty) return null;
    return email.trim();
  }

  bool get _isLoggedIn => Hive.box('authBox').get('token') != null;

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
      final going = ((data['going_users'] as List?) ?? []).map((e) => e.toString()).toList();
      final notGoing = ((data['not_going_users'] as List?) ?? []).map((e) => e.toString()).toList();
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
          rsvpStatus: base.rsvpStatus,
          goingUsers: going,
          notGoingUsers: notGoing,
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
    final notGoingSelected = me != null && event.notGoingUsers.contains(me);
    final goingCount = event.goingUsers.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подробности события'),
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
                        child: goingSelected
                            ? FilledButton.icon(
                                onPressed: () => _setRsvp(0),
                                icon: const Icon(Icons.check),
                                label: const Text('Я приду'),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => _setRsvp(1),
                                icon: const Icon(Icons.check),
                                label: const Text('Я приду'),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: notGoingSelected
                            ? FilledButton.icon(
                                onPressed: () => _setRsvp(0),
                                icon: const Icon(Icons.close),
                                label: const Text('Не приду'),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => _setRsvp(-1),
                                icon: const Icon(Icons.close),
                                label: const Text('Не приду'),
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
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.person),
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
                                      final myId =
                                          Hive.box('authBox').get('userId') as String?;
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
                ],
              ),
            ),
    );
  }
}

