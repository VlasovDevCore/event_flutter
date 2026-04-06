/// Какой чат сейчас открыт на экране — чтобы не дублировать push, когда пользователь уже в этом чате.
class ChatPresenceTracker {
  ChatPresenceTracker._();
  static final ChatPresenceTracker instance = ChatPresenceTracker._();

  String? _directPeerUserId;
  String? _eventChatEventId;

  void setDirectPeer(String? peerUserId) {
    _directPeerUserId = peerUserId;
  }

  void setEventChat(String? eventId) {
    _eventChatEventId = eventId;
  }

  bool shouldSuppressDirect(String peerUserId) =>
      _directPeerUserId != null && _directPeerUserId == peerUserId;

  bool shouldSuppressEvent(String eventId) =>
      _eventChatEventId != null && _eventChatEventId == eventId;
}
