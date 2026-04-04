class EventMessage {
  /// ISO из API (UTC с Z) → локальное время устройства для отображения.
  static DateTime parseDateTimeFromApi(String raw) {
    final dt = DateTime.parse(raw.trim());
    return dt.isUtc ? dt.toLocal() : dt;
  }

  static DateTime? tryParseDateTimeFromApi(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return parseDateTimeFromApi(raw);
  }

  final String id;
  final String text;
  final String userEmail;
  final String? userDisplayName;
  final DateTime createdAt;
  final String? userId;
  final String? avatarUrl; // Добавляем поле для аватарки
  final bool isViewed;
  final DateTime? viewedAt;
  final DateTime? editedAt;

  /// Ответ на исходное сообщение (id в этом же чате).
  final String? replyToId;
  /// Текст исходного сообщения (для превью).
  final String? replyToText;
  final String? replyToAuthorName;
  final String? replyToAuthorEmail;

  const EventMessage({
    required this.id,
    required this.text,
    required this.userEmail,
    this.userDisplayName,
    required this.createdAt,
    this.userId,
    this.avatarUrl, // Добавляем в конструктор
    this.isViewed = false,
    this.viewedAt,
    this.editedAt,
    this.replyToId,
    this.replyToText,
    this.replyToAuthorName,
    this.replyToAuthorEmail,
  });

  /// Подпись автора цитируемого сообщения для UI.
  String? get replyQuoteAuthorLabel {
    if (replyToAuthorName != null && replyToAuthorName!.trim().isNotEmpty) {
      return replyToAuthorName!.trim();
    }
    if (replyToAuthorEmail != null && replyToAuthorEmail!.trim().isNotEmpty) {
      return replyToAuthorEmail!.trim();
    }
    return null;
  }

  factory EventMessage.fromApi(Map<String, dynamic> map) {
    final viewedAtRaw =
        map['viewed_at'] ?? map['read_at'] ?? map['seen_at'] ?? map['readAt'];
    DateTime? viewedAt;
    if (viewedAtRaw is String && viewedAtRaw.isNotEmpty) {
      viewedAt = EventMessage.tryParseDateTimeFromApi(viewedAtRaw);
    }

    final isViewedRaw = map['is_viewed'] ?? map['is_read'] ?? map['isSeen'];
    final isViewed = _parseBool(isViewedRaw) || viewedAt != null;

    final editedAtRaw = map['edited_at'] ?? map['editedAt'];
    DateTime? editedAt;
    if (editedAtRaw is String && editedAtRaw.isNotEmpty) {
      editedAt = EventMessage.tryParseDateTimeFromApi(editedAtRaw);
    }

    final replyToRaw = map['reply_to_id'];
    String? replyToId;
    if (replyToRaw != null && replyToRaw.toString().trim().isNotEmpty) {
      replyToId = replyToRaw.toString();
    }

    return EventMessage(
      id: map['id'].toString(),
      text: map['text'] as String,
      userEmail: (map['user_email'] as String?) ?? '',
      userDisplayName: map['user_display_name'] as String?,
      createdAt: EventMessage.parseDateTimeFromApi(map['created_at'] as String),
      userId: map['user_id']?.toString(),
      avatarUrl: map['avatar_url'] as String?, // Добавляем парсинг аватарки
      isViewed: isViewed,
      viewedAt: viewedAt,
      editedAt: editedAt,
      replyToId: replyToId,
      replyToText: map['reply_to_text'] as String?,
      replyToAuthorName: map['reply_to_author_name'] as String?,
      replyToAuthorEmail: map['reply_to_author_email'] as String?,
    );
  }

  // Геттер для отображения имени
  String get displayName {
    if (userDisplayName != null && userDisplayName!.isNotEmpty) {
      return userDisplayName!;
    }
    return userEmail;
  }

  EventMessage copyWith({
    String? id,
    String? text,
    String? userEmail,
    String? userDisplayName,
    DateTime? createdAt,
    String? userId,
    String? avatarUrl,
    bool? isViewed,
    DateTime? viewedAt,
    DateTime? editedAt,
    String? replyToId,
    String? replyToText,
    String? replyToAuthorName,
    String? replyToAuthorEmail,
  }) {
    return EventMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      userEmail: userEmail ?? this.userEmail,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isViewed: isViewed ?? this.isViewed,
      viewedAt: viewedAt ?? this.viewedAt,
      editedAt: editedAt ?? this.editedAt,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToAuthorName: replyToAuthorName ?? this.replyToAuthorName,
      replyToAuthorEmail: replyToAuthorEmail ?? this.replyToAuthorEmail,
    );
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
      'is_viewed': isViewed,
      'viewed_at': viewedAt?.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'reply_to_id': replyToId,
      'reply_to_text': replyToText,
      'reply_to_author_name': replyToAuthorName,
      'reply_to_author_email': replyToAuthorEmail,
    };
  }
}

bool _parseBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == 't' || s == '1';
  }
  if (v is int) return v != 0;
  return false;
}
