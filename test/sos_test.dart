import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/core/utils/sms_link.dart';
import 'package:ride_club/models/sos_alert.dart';

void main() {
  test('SosAlert.fromMap with location', () {
    final SosAlert s = SosAlert.fromMap('s1', <dynamic, dynamic>{
      'senderId': 'u1',
      'senderName': 'A',
      'lat': 18.5,
      'lng': 73.4,
      'active': true,
      'startedAt': 1000,
    });
    expect(s.hasLocation, isTrue);
    expect(s.active, isTrue);
    expect(s.lat, 18.5);
  });

  test('SosAlert.fromMap without location', () {
    final SosAlert s = SosAlert.fromMap('s2', <dynamic, dynamic>{
      'senderId': 'u1',
      'senderName': 'A',
      'active': true,
      'startedAt': 1,
    });
    expect(s.hasLocation, isFalse);
  });

  test('emergencySmsUri embeds OSM link when coords present', () {
    final Uri uri = emergencySmsUri('+911234567890', 'Asha', 18.5, 73.4);
    expect(uri.scheme, 'sms');
    expect(uri.path, '+911234567890');
    expect(uri.query, contains('openstreetmap.org'));
    expect(Uri.decodeFull(uri.query), contains('Asha'));
  });

  test('emergencySmsUri without coords still builds', () {
    final Uri uri = emergencySmsUri('+911234567890', 'Asha', null, null);
    expect(uri.scheme, 'sms');
    expect(Uri.decodeFull(uri.query), contains('Location unavailable'));
  });
}
