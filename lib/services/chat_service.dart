import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// Realtime group chat over RTDB `chats/{rideId}/messages`, with typing flags
/// on the presence node and a client-side `lastRead` marker for unread counts.
class ChatService extends GetxService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  static const Duration _timeout = Duration(seconds: 15);

  DatabaseReference _messages(String rideId) =>
      _db.ref('chats/$rideId/messages');
  DatabaseReference _lastRead(String rideId, String uid) =>
      _db.ref('lastRead/$rideId/$uid');
  DatabaseReference _typing(String rideId, String uid) =>
      _db.ref('presence/$rideId/$uid/typing');

  List<ChatMessage> _parse(Map<dynamic, dynamic>? raw) {
    if (raw == null) return <ChatMessage>[];
    final List<ChatMessage> list = raw.entries
        .map((MapEntry<dynamic, dynamic> e) => ChatMessage.fromMap(
              e.key as String,
              e.value as Map<dynamic, dynamic>,
            ))
        .toList()
      ..sort((ChatMessage a, ChatMessage b) =>
          a.timestamp.compareTo(b.timestamp));
    return list;
  }

  Stream<List<ChatMessage>> watchMessages(String rideId) {
    return _messages(rideId).limitToLast(200).onValue.map(
          (DatabaseEvent e) =>
              _parse(e.snapshot.value as Map<dynamic, dynamic>?),
        );
  }

  Future<void> sendText(String rideId, String text) async {
    final String t = text.trim();
    if (t.isEmpty) return;
    await _push(rideId, <String, dynamic>{'type': 'text', 'text': t});
  }

  Future<void> sendLocation(String rideId, double lat, double lng) async {
    await _push(
        rideId, <String, dynamic>{'type': 'location', 'lat': lat, 'lng': lng});
  }

  Future<void> _push(String rideId, Map<String, dynamic> body) async {
    final String? uid = _auth.uid;
    if (uid == null) return;
    final profile = await _users.fetch(uid);
    final Map<String, dynamic> data = <String, dynamic>{
      'senderId': uid,
      'senderName': profile?.name ?? 'Rider',
      'senderPhoto': profile?.photoUrl,
      'timestamp': ServerValue.timestamp,
      'readBy': <String, dynamic>{uid: true},
      ...body,
    };
    await _messages(rideId).push().set(data).timeout(
          _timeout,
          onTimeout: () =>
              throw Exception("Couldn't send. Check your connection."),
        );
  }

  Future<void> markRead(String rideId, List<ChatMessage> visible) async {
    final String? uid = _auth.uid;
    if (uid == null) return;
    await _lastRead(rideId, uid).set(ServerValue.timestamp);
    for (final ChatMessage m in visible) {
      if (m.senderId == uid || m.readBy.contains(uid)) continue;
      _messages(rideId)
          .child(m.id)
          .child('readBy')
          .child(uid)
          .set(true)
          .catchError((Object e) => Log.e('readBy write failed', error: e));
    }
  }

  void setTyping(String rideId, bool typing) {
    final String? uid = _auth.uid;
    if (uid == null) return;
    _typing(rideId, uid).set(typing);
  }

  Stream<List<String>> watchTyping(String rideId) {
    final String? uid = _auth.uid;
    return _db.ref('presence/$rideId').onValue.map((DatabaseEvent e) {
      final Map<dynamic, dynamic>? raw =
          e.snapshot.value as Map<dynamic, dynamic>?;
      if (raw == null) return <String>[];
      final List<String> typers = <String>[];
      raw.forEach((dynamic key, dynamic value) {
        if (key == uid) return;
        if (value is Map && value['typing'] == true) {
          typers.add(key as String);
        }
      });
      return typers;
    });
  }

  Stream<int> unreadCount(String rideId) {
    final String? uid = _auth.uid;
    if (uid == null) return Stream<int>.value(0);
    return _messages(rideId).limitToLast(200).onValue.asyncMap(
      (DatabaseEvent e) async {
        final List<ChatMessage> msgs =
            _parse(e.snapshot.value as Map<dynamic, dynamic>?);
        final DataSnapshot lr = await _lastRead(rideId, uid).get();
        final int lastRead = (lr.value as num?)?.toInt() ?? 0;
        // First-ever open (no lastRead): treat all as read to avoid a huge count.
        if (lastRead == 0) return 0;
        return unreadCountFor(msgs, lastRead, uid);
      },
    );
  }
}
