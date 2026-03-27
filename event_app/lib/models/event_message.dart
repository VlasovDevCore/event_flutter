class EventMessage {
  final String id;
  final String text;
  final String userEmail;
  final String? userDisplayName;
  final DateTime createdAt;
  final String? userId;
  final String? avatarUrl; // Добавляем поле для аватарки

  const EventMessage({
    required this.id,
    required this.text,
    required this.userEmail,
    this.userDisplayName,
    required this.createdAt,
    this.userId,
    this.avatarUrl, // Добавляем в конструктор
  });

  factory EventMessage.fromApi(Map<String, dynamic> map) {
    return EventMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      userEmail: map['user_email'] as String,
      userDisplayName: map['user_display_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      userId: map['user_id'] as String?,
      avatarUrl: map['avatar_url'] as String?, // Добавляем парсинг аватарки
    );
  }

  // Геттер для отображения имени
  String get displayName {
    if (userDisplayName != null && userDisplayName!.isNotEmpty) {
      return userDisplayName!;
    }
    return userEmail;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'user_email': userEmail,
      'user_display_name': userDisplayName,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      'avatar_url': avatarUrl,
    };
  }
}
