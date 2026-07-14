/// A single local GPS reading enriched with heading and battery, ready to
/// write to Realtime Database.
class RidePosition {
  final double lat;
  final double lng;
  final double speed; // m/s
  final double heading; // degrees 0–360
  final int battery; // 0–100

  const RidePosition({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.battery,
  });

  Map<String, dynamic> toRtdb() => <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'heading': heading,
        'battery': battery,
      };
}
