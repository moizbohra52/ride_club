/// A chat message stored at `chats/{rideId}/messages/{msgId}`.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String type; // 'text' | 'location'
  final String? text;
  final double? lat;
  final double? lng;
  final int timestamp; // epoch ms
  final Set<String> readBy;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.type,
    this.text,
    this.lat,
    this.lng,
    required this.timestamp,
    this.readBy = const <String>{},
  });

  bool isMine(String uid) => senderId == uid;
  bool get isLocation => type == 'location';

  /// How many people other than the sender have seen this message.
  int get seenByCount => readBy.where((String u) => u != senderId).length;

  String get timeText {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final int h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final String m = d.minute.toString().padLeft(2, '0');
    final String ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> m) {
    final dynamic rb = m['readBy'];
    final Set<String> read = rb is Map
        ? rb.entries
            .where((MapEntry<dynamic, dynamic> e) => e.value == true)
            .map((MapEntry<dynamic, dynamic> e) => e.key.toString())
            .toSet()
        : <String>{};
    final dynamic ts = m['timestamp'];
    return ChatMessage(
      id: id,
      senderId: (m['senderId'] ?? '') as String,
      senderName: (m['senderName'] ?? '') as String,
      senderPhoto: m['senderPhoto'] as String?,
      type: (m['type'] ?? 'text') as String,
      text: m['text'] as String?,
      lat: _d(m['lat']),
      lng: _d(m['lng']),
      timestamp: ts is num ? ts.toInt() : 0,
      readBy: read,
    );
  }
}

/// Count of messages newer than [lastReadMs] that were not sent by [myUid].
int unreadCountFor(List<ChatMessage> msgs, int lastReadMs, String myUid) {
  return msgs
      .where((ChatMessage m) => m.timestamp > lastReadMs && m.senderId != myUid)
      .length;
}
