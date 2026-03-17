import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../services/api_client.dart';
import '../chat/event_chat_screen.dart';
import '../events/event_details_screen.dart';

/// Список комнат (событий), где пользователь участвует (RSVP «приду»).
/// По нажатию открывается чат; после окончания события чат остаётся.
class MyRoomsScreen extends StatefulWidget {
  const MyRoomsScreen({super.key});

  @override
  State<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

class _MyRoomsScreenState extends State<MyRoomsScreen> {
  List<Event> _rooms = [];
  bool _loading = true;
  String? _error;

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.instance;
      final list = await client.getList('/events/my/rooms', withAuth: true);
      final events = list.map((raw) {
        final map = raw as Map<String, dynamic>;
        return Event.fromApiMap(map);
      }).toList();
      setState(() {
        _rooms = events;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _rooms = [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _rooms = [];
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Комнаты, где я участвую'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadRooms,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadRooms,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : _rooms.isEmpty
                  ? Center(
                      child: Text(
                        'Вы пока не участвуете ни в одном событии.\nОтметьте «Я приду» в деталях события.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _rooms.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final event = _rooms[index];
                        final isEnded = event.endsAt != null && event.endsAt!.isBefore(DateTime.now());
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(event.markerColorValue),
                            child: Icon(
                              IconData(
                                event.markerIconCodePoint,
                                fontFamily: 'MaterialIcons',
                              ),
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          title: Text(event.title),
                          subtitle: isEnded
                              ? Text(
                                  'Событие завершено',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          trailing: const Icon(Icons.chat),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EventChatScreen(event: event),
                              ),
                            );
                          },
                          onLongPress: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EventDetailsScreen(event: event),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}

