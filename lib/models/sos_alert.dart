/// An SOS alert stored at `sos/{rideId}/{sosId}`.
class SosAlert {
  final String sosId;
  final String senderId;
  final String senderName;
  final double? lat;
  final double? lng;
  final bool active;
  final int startedAt; // epoch ms

  const SosAlert({
    required this.sosId,
    required this.senderId,
    required this.senderName,
    this.lat,
    this.lng,
    required this.active,
    required this.startedAt,
  });

  bool get hasLocation => lat != null && lng != null;

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

  factory SosAlert.fromMap(String id, Map<dynamic, dynamic> m) => SosAlert(
        sosId: id,
        senderId: (m['senderId'] ?? '') as String,
        senderName: (m['senderName'] ?? '') as String,
        lat: _d(m['lat']),
        lng: _d(m['lng']),
        active: (m['active'] ?? false) as bool,
        startedAt: m['startedAt'] is num ? (m['startedAt'] as num).toInt() : 0,
      );
}
