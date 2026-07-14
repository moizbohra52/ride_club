import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/models/ride.dart';
import 'package:ride_club/models/place_result.dart';

void main() {
  test('Ride.isHost true for creator', () {
    const r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
    );
    expect(r.isHost('u1'), isTrue);
    expect(r.isHost('u2'), isFalse);
  });

  test('Ride.destinationLabel falls back when null', () {
    const r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
    );
    expect(r.destinationLabel, 'No destination set');
    expect(r.isActive, isTrue);
  });

  test('PlaceResult.fromJson parses Nominatim shape', () {
    final PlaceResult p = PlaceResult.fromJson(<String, dynamic>{
      'lat': '30.12',
      'lon': '78.45',
      'display_name': 'Rishikesh, India',
    });
    expect(p.lat, closeTo(30.12, 0.001));
    expect(p.lng, closeTo(78.45, 0.001));
    expect(p.displayName, 'Rishikesh, India');
  });
}
