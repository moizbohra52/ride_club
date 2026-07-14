import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/models/chat_message.dart';

void main() {
  test('fromMap parses text message + seenByCount excludes sender', () {
    final ChatMessage m = ChatMessage.fromMap('m1', <dynamic, dynamic>{
      'senderId': 'u1',
      'senderName': 'A',
      'type': 'text',
      'text': 'hi',
      'timestamp': 1000,
      'readBy': <dynamic, dynamic>{'u1': true, 'u2': true},
    });
    expect(m.type, 'text');
    expect(m.text, 'hi');
    expect(m.isLocation, isFalse);
    expect(m.seenByCount, 1); // readBy minus sender u1
  });

  test('fromMap parses location message', () {
    final ChatMessage m = ChatMessage.fromMap('m2', <dynamic, dynamic>{
      'senderId': 'u1',
      'senderName': 'A',
      'type': 'location',
      'lat': 18.5,
      'lng': 73.4,
      'timestamp': 2000,
    });
    expect(m.isLocation, isTrue);
    expect(m.lat, 18.5);
    expect(m.lng, 73.4);
  });

  test('unreadCountFor counts newer inbound messages only', () {
    final List<ChatMessage> msgs = <ChatMessage>[
      ChatMessage.fromMap('a', <dynamic, dynamic>{
        'senderId': 'u2',
        'type': 'text',
        'text': 'x',
        'timestamp': 100,
      }),
      ChatMessage.fromMap('b', <dynamic, dynamic>{
        'senderId': 'u2',
        'type': 'text',
        'text': 'y',
        'timestamp': 300,
      }),
      ChatMessage.fromMap('c', <dynamic, dynamic>{
        'senderId': 'me',
        'type': 'text',
        'text': 'z',
        'timestamp': 400,
      }),
    ];
    // Only 'b' (300 > 200, not mine). 'c' is mine, 'a' is older.
    expect(unreadCountFor(msgs, 200, 'me'), 1);
  });
}
