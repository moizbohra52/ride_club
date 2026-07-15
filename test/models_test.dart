import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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

  test('Ride.orderedStops chains origin + waypoints + destination', () {
    const Ride r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
      origin: RideDestination(lat: 1, lng: 1, label: 'Indore'),
      waypoints: <RideDestination>[
        RideDestination(lat: 2, lng: 2, label: 'Manawar'),
        RideDestination(lat: 3, lng: 3, label: 'Kukshi'),
      ],
      destination: RideDestination(lat: 4, lng: 4, label: 'Dahi'),
    );
    expect(r.orderedStops.map((s) => s.label).toList(),
        <String>['Indore', 'Manawar', 'Kukshi', 'Dahi']);
  });

  test('Ride.orderedStops omits nulls (empty ride)', () {
    const Ride r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
    );
    expect(r.orderedStops, isEmpty);
    expect(r.waypoints, isEmpty);
    expect(r.plannedRoute, isNull);
  });

  test('Ride.toMap round-trips origin/waypoints/plannedRoute', () {
    const Ride r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
      origin: RideDestination(lat: 1, lng: 1, label: 'A'),
      waypoints: <RideDestination>[RideDestination(lat: 2, lng: 2, label: 'B')],
      destination: RideDestination(lat: 3, lng: 3, label: 'C'),
      plannedRoute: <LatLng>[LatLng(1, 1), LatLng(3, 3)],
      plannedDistanceMeters: 1234,
      plannedDurationSeconds: 600,
    );
    final Map<String, dynamic> m = r.toMap();
    expect((m['origin'] as Map)['label'], 'A');
    expect((m['waypoints'] as List).length, 1);
    expect((m['plannedRoute'] as List).length, 2);
    expect((m['plannedRoute'] as List).first,
        <String, dynamic>{'lat': 1.0, 'lng': 1.0});
    expect(m['plannedDistanceMeters'], 1234);
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
