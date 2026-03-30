import '../../../models/event_message.dart';
import '../../../services/api_client.dart';

class ChatRepository {
  final String eventId;
  final ApiClient _client = ApiClient.instance;

  ChatRepository(this.eventId);

  Future<List<EventMessage>> getMessages() async {
    final list = await _client.getList(
      '/events/$eventId/messages',
      withAuth: true,
    );
    return list
        .map((e) => EventMessage.fromApi(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventMessage> sendMessage(String text) async {
    final data = await _client.post(
      '/events/$eventId/messages',
      body: {'text': text},
      withAuth: true,
    );
    return EventMessage.fromApi(data);
  }

  Future<EventMessage> updateMessage(String messageId, String text) async {
    final data = await _client.put(
      '/events/$eventId/messages/$messageId',
      body: {'text': text},
      withAuth: true,
    );
    return EventMessage.fromApi(data);
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.delete(
      '/events/$eventId/messages/$messageId',
      withAuth: true,
    );
  }

  Future<void> markMessagesViewed(String upToId) async {
    await _client.post(
      '/events/$eventId/messages/view',
      body: {'up_to_id': upToId},
      withAuth: true,
    );
  }
}
