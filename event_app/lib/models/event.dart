class Event {
  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.lat,
    required this.lon,
    required this.createdAt,
    required this.markerColorValue,
  required this.markerIconCodePoint,
  required this.rsvpStatus,
  required this.goingUsers,
  required this.notGoingUsers,
  this.goingUserProfiles = const [],
  this.notGoingUserProfiles = const [],
  this.endsAt,
  });

  final String id;
  final String title;
  final String description;
  final double lat;
  final double lon;
  final DateTime createdAt;
  final int markerColorValue;
  final int markerIconCodePoint;
  /// 0 = не выбрано, 1 = приду, -1 = не приду
  final int rsvpStatus;
  /// Список имён/идентификаторов пользователей (пока используем email)
  final List<String> goingUsers;
  final List<String> notGoingUsers;
  /// Расширенные данные участников (если пришли из API)
  final List<EventUserProfile> goingUserProfiles;
  final List<EventUserProfile> notGoingUserProfiles;
  /// До какой даты событие актуально (макс. неделя вперёд при создании).
  final DateTime? endsAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'lat': lat,
      'lon': lon,
      'createdAt': createdAt.toIso8601String(),
      'markerColorValue': markerColorValue,
      'markerIconCodePoint': markerIconCodePoint,
      'rsvpStatus': rsvpStatus,
      'goingUsers': goingUsers,
      'notGoingUsers': notGoingUsers,
      'goingUserProfiles': goingUserProfiles.map((e) => e.toMap()).toList(),
      'notGoingUserProfiles': notGoingUserProfiles.map((e) => e.toMap()).toList(),
      if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
    };
  }

  factory Event.fromMap(Map<dynamic, dynamic> map) {
    final goingRaw = (map['goingUsers'] as List?) ?? const [];
    final notGoingRaw = (map['notGoingUsers'] as List?) ?? const [];
    final goingProfilesRaw = (map['goingUserProfiles'] as List?) ?? const [];
    final notGoingProfilesRaw = (map['notGoingUserProfiles'] as List?) ?? const [];

    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      lat: (map['lat'] as num).toDouble(),
      lon: (map['lon'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      markerColorValue: (map['markerColorValue'] as int?) ?? 0xFF2196F3,
      markerIconCodePoint:
          (map['markerIconCodePoint'] as int?) ?? 0xE1C7, // Icons.flutter_dash
      rsvpStatus: (map['rsvpStatus'] as int?) ?? 0,
      goingUsers: goingRaw.map((e) => e.toString()).toList(),
      notGoingUsers: notGoingRaw.map((e) => e.toString()).toList(),
      goingUserProfiles: goingProfilesRaw
          .whereType<Map>()
          .map((e) => EventUserProfile.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      notGoingUserProfiles: notGoingProfilesRaw
          .whereType<Map>()
          .map((e) => EventUserProfile.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      endsAt: map['endsAt'] != null ? DateTime.parse(map['endsAt'] as String) : null,
    );
  }

  /// Парсинг ответа API (snake_case: created_at, going_users, not_going_users и т.д.)
  factory Event.fromApiMap(Map<String, dynamic> map) {
    final goingRaw = (map['going_users'] as List?) ?? (map['goingUsers'] as List?) ?? const [];
    final notGoingRaw = (map['not_going_users'] as List?) ?? (map['notGoingUsers'] as List?) ?? const [];

    List<EventUserProfile> parseProfiles(List raw) {
      return raw.where((e) => e is Map).map((e) {
        return EventUserProfile.fromApiMap(Map<String, dynamic>.from(e as Map));
      }).toList();
    }

    List<String> parseEmails(List raw) {
      return raw.map((e) {
        if (e is String) return e;
        if (e is Map && e['email'] != null) return e['email'].toString();
        return e.toString();
      }).toList();
    }

    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      lat: ((map['lat'] as num?) ?? 0).toDouble(),
      lon: ((map['lon'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.parse((map['created_at'] ?? map['createdAt']) as String),
      markerColorValue: int.parse((map['marker_color_value'] ?? map['markerColorValue'] ?? 0xFF2196F3).toString()),
      markerIconCodePoint: int.parse((map['marker_icon_code'] ?? map['markerIconCodePoint'] ?? 0xE1C7).toString()),
      rsvpStatus: 0,
      goingUsers: parseEmails(goingRaw),
      notGoingUsers: parseEmails(notGoingRaw),
      goingUserProfiles: parseProfiles(goingRaw),
      notGoingUserProfiles: parseProfiles(notGoingRaw),
      endsAt: map['ends_at'] != null || map['endsAt'] != null
          ? DateTime.parse((map['ends_at'] ?? map['endsAt']) as String)
          : null,
    );
  }
}

class EventUserProfile {
  const EventUserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  factory EventUserProfile.fromApiMap(Map<String, dynamic> map) {
    return EventUserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString(),
      username: map['username']?.toString(),
      displayName: (map['display_name'] ?? map['displayName'])?.toString(),
      avatarUrl: (map['avatar_url'] ?? map['avatarUrl'])?.toString(),
    );
  }

  factory EventUserProfile.fromMap(Map<String, dynamic> map) {
    return EventUserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString(),
      username: map['username']?.toString(),
      displayName: map['displayName']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };

  final String id;
  final String? email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
}

