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
  this.creatorId,
  this.creatorEmail,
  this.creatorName,
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
  final String? creatorId;
  final String? creatorEmail;
  final String? creatorName;

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
      if (creatorId != null) 'creatorId': creatorId,
      if (creatorEmail != null) 'creatorEmail': creatorEmail,
      if (creatorName != null) 'creatorName': creatorName,
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
      creatorId: map['creatorId']?.toString(),
      creatorEmail: map['creatorEmail']?.toString(),
      creatorName: map['creatorName']?.toString(),
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

    int parseRsvpStatusValue(dynamic value) {
      if (value == null) return 0;
      if (value is num) {
        if (value > 0) return 1;
        if (value < 0) return -1;
        return 0;
      }

      final normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty) return 0;

      if (normalized == '1' ||
          normalized == 'true' ||
          normalized == 'going' ||
          normalized == 'yes' ||
          normalized == 'accepted') {
        return 1;
      }
      if (normalized == '-1' ||
          normalized == 'false' ||
          normalized == 'not_going' ||
          normalized == 'not-going' ||
          normalized == 'declined' ||
          normalized == 'no') {
        return -1;
      }

      final parsed = int.tryParse(normalized);
      if (parsed == null) return 0;
      if (parsed > 0) return 1;
      if (parsed < 0) return -1;
      return 0;
    }

    int parseRsvpStatus() {
      final candidates = [
        map['rsvp_status'],
        map['rsvpStatus'],
        map['current_user_rsvp_status'],
        map['currentUserRsvpStatus'],
        map['my_rsvp_status'],
        map['myRsvpStatus'],
        map['status'],
      ];

      for (final value in candidates) {
        final parsed = parseRsvpStatusValue(value);
        if (parsed != 0) return parsed;
      }

      return 0;
    }

    String? parseCreatorId() {
      final nestedCandidates = [
        map['creator'],
        map['created_by'],
        map['author'],
        map['user'],
      ];
      for (final raw in nestedCandidates) {
        if (raw is Map) {
          final nested = Map<String, dynamic>.from(raw);
          final id = (nested['id'] ??
                  nested['user_id'] ??
                  nested['userId'] ??
                  nested['creator_id'] ??
                  nested['creatorId'])
              ?.toString();
          if (id != null && id.trim().isNotEmpty) return id.trim();
        }
      }
      final flat = (map['created_by_user_id'] ??
              map['createdByUserId'] ??
              map['creator_id'] ??
              map['creatorId'] ??
              map['user_id'] ??
              map['userId'])
          ?.toString();
      if (flat == null || flat.trim().isEmpty) return null;
      return flat.trim();
    }

    String? parseCreatorEmail() {
      final nestedCandidates = [
        map['creator'],
        map['created_by'],
        map['author'],
        map['user'],
      ];
      for (final raw in nestedCandidates) {
        if (raw is Map) {
          final nested = Map<String, dynamic>.from(raw);
          final email =
              (nested['email'] ?? nested['creator_email'] ?? nested['creatorEmail'])?.toString();
          if (email != null && email.trim().isNotEmpty) return email.trim();
        }
      }
      final flat = (map['created_by_email'] ??
              map['createdByEmail'] ??
              map['creator_email'] ??
              map['creatorEmail'] ??
              map['email'])
          ?.toString();
      if (flat == null || flat.trim().isEmpty) return null;
      return flat.trim();
    }

    String? parseCreatorName() {
      final nestedCandidates = [
        map['creator'],
        map['created_by'],
        map['author'],
        map['user'],
      ];
      for (final raw in nestedCandidates) {
        if (raw is Map) {
          final nested = Map<String, dynamic>.from(raw);
          final displayName = (nested['display_name'] ??
                  nested['displayName'] ??
                  nested['full_name'] ??
                  nested['fullName'] ??
                  nested['name'] ??
                  nested['username'])
              ?.toString();
          if (displayName != null && displayName.trim().isNotEmpty) {
            return displayName.trim();
          }
        }
      }
      final flat = (map['created_by_name'] ??
              map['createdByName'] ??
              map['created_by_display_name'] ??
              map['createdByDisplayName'] ??
              map['created_by_username'] ??
              map['createdByUsername'] ??
              map['creator_name'] ??
              map['creatorName'] ??
              map['author_name'] ??
              map['authorName'])
          ?.toString();
      if (flat == null || flat.trim().isEmpty) return null;
      return flat.trim();
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
      rsvpStatus: parseRsvpStatus(),
      goingUsers: parseEmails(goingRaw),
      notGoingUsers: parseEmails(notGoingRaw),
      goingUserProfiles: parseProfiles(goingRaw),
      notGoingUserProfiles: parseProfiles(notGoingRaw),
      endsAt: map['ends_at'] != null || map['endsAt'] != null
          ? DateTime.parse((map['ends_at'] ?? map['endsAt']) as String)
          : null,
      creatorId: parseCreatorId(),
      creatorEmail: parseCreatorEmail(),
      creatorName: parseCreatorName(),
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
    this.status = 1,
  });

  factory EventUserProfile.fromApiMap(Map<String, dynamic> map) {
    return EventUserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString(),
      username: map['username']?.toString(),
      displayName: (map['display_name'] ?? map['displayName'])?.toString(),
      avatarUrl: (map['avatar_url'] ?? map['avatarUrl'])?.toString(),
      status: int.tryParse((map['status'] ?? map['rsvp_status'] ?? 1).toString()) ?? 1,
    );
  }

  factory EventUserProfile.fromMap(Map<String, dynamic> map) {
    return EventUserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString(),
      username: map['username']?.toString(),
      displayName: map['displayName']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      status: int.tryParse((map['status'] ?? map['rsvpStatus'] ?? 1).toString()) ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'status': status,
      };

  final String id;
  final String? email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  /// 1 = иду, -1 = не иду, 0 = без статуса
  final int status;
}

