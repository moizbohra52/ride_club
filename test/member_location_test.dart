import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/models/member_location.dart';

void main() {
  test('speedKmh converts m/s', () {
    const MemberLocation m = MemberLocation(
      uid: 'u',
      lat: 0,
      lng: 0,
      speed: 10,
      heading: 0,
      battery: 50,
      updatedAt: 0,
      online: true,
      lastSeen: 0,
    );
    expect(m.speedKmh, closeTo(36.0, 0.1));
  });

  test('lastSeenText formats minutes for offline member', () {
    const MemberLocation m = MemberLocation(
      uid: 'u',
      lat: 0,
      lng: 0,
      speed: 0,
      heading: 0,
      battery: 50,
      updatedAt: 0,
      online: false,
      lastSeen: 1000, // seen at t=1s
    );
    // now = 1000 + 180000ms → 180s elapsed → 3m
    expect(m.lastSeenText(181000), 'last seen 3m ago');
  });

  test('lastSeenText is Offline when never seen', () {
    const MemberLocation m = MemberLocation(
      uid: 'u',
      lat: 0,
      lng: 0,
      speed: 0,
      heading: 0,
      battery: 50,
      updatedAt: 0,
      online: false,
      lastSeen: 0,
    );
    expect(m.lastSeenText(999999), 'Offline');
  });

  test('online member shows Online', () {
    const MemberLocation m = MemberLocation(
      uid: 'u',
      lat: 0,
      lng: 0,
      speed: 0,
      heading: 0,
      battery: 50,
      updatedAt: 0,
      online: true,
      lastSeen: 999,
    );
    expect(m.lastSeenText(999999), 'Online');
  });

  test('fromMaps merges location + presence', () {
    final MemberLocation m = MemberLocation.fromMaps(
      'u1',
      <dynamic, dynamic>{
        'lat': 1.0,
        'lng': 2.0,
        'speed': 5.0,
        'heading': 90.0,
        'battery': 80,
        'updatedAt': 1000,
      },
      <dynamic, dynamic>{'online': true, 'lastSeen': 1000},
    );
    expect(m.lat, 1.0);
    expect(m.lng, 2.0);
    expect(m.online, isTrue);
    expect(m.battery, 80);
    expect(m.heading, 90.0);
  });
}
