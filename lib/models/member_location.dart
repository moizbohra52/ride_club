/// A remote member's live state, merged from RTDB `locations/{rideId}/{uid}`
/// and `presence/{rideId}/{uid}`.
class MemberLocation {
  final String uid;
  final double lat;
  final double lng;
  final double speed; // m/s
  final double heading; // deg
  final int battery;
  final int updatedAt; // epoch ms
  final bool online;
  final int lastSeen; // epoch ms

  const MemberLocation({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.battery,
    required this.updatedAt,
    required this.online,
    required this.lastSeen,
  });

  double get speedKmh => speed * 3.6;

  String lastSeenText(int nowMs) {
    if (online) return 'Online';
    if (lastSeen == 0) return 'Offline';
    final int secs = ((nowMs - lastSeen) / 1000).round();
    if (secs < 60) return 'last seen ${secs}s ago';
    final int mins = (secs / 60).round();
    if (mins < 60) return 'last seen ${mins}m ago';
    final int hrs = (mins / 60).round();
    return 'last seen ${hrs}h ago';
  }

  static double _d(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
  static int _i(dynamic v) => v == null ? 0 : (v as num).toInt();

  factory MemberLocation.fromMaps(
    String uid,
    Map<dynamic, dynamic>? loc,
    Map<dynamic, dynamic>? pres,
  ) {
    final Map<dynamic, dynamic> l = loc ?? const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> p = pres ?? const <dynamic, dynamic>{};
    return MemberLocation(
      uid: uid,
      lat: _d(l['lat']),
      lng: _d(l['lng']),
      speed: _d(l['speed']),
      heading: _d(l['heading']),
      battery: _i(l['battery']),
      updatedAt: _i(l['updatedAt']),
      online: (p['online'] ?? false) as bool,
      lastSeen: _i(p['lastSeen']),
    );
  }
}
