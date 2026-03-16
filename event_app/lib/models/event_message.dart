class EventMessage {
  EventMessage({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.userEmail,
  });

  final String id;
  final String eventId;
  final String userId;
  final String? userEmail;
  final String text;
  final DateTime createdAt;

  factory EventMessage.fromApi(Map<String, dynamic> map) {
    return EventMessage(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      userId: map['user_id'] as String,
      userEmail: map['user_email'] as String?,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
