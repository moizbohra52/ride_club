import 'package:cloud_firestore/cloud_firestore.dart';

/// A ride destination pin, resolved from Nominatim search.
class RideDestination {
  final double lat;
  final double lng;
  final String label;
  const RideDestination({
    required this.lat,
    required this.lng,
    required this.label,
  });

  Map<String, dynamic> toMap() =>
      <String, dynamic>{'lat': lat, 'lng': lng, 'label': label};

  factory RideDestination.fromMap(Map<String, dynamic> m) => RideDestination(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        label: (m['label'] ?? '') as String,
      );
}

/// A ride, stored at `rides/{id}`. The host is [createdBy]; others join via
/// [code] and a host-approved request.
class Ride {
  final String id;
  final String name;
  final String code;
  final RideDestination? destination;
  final String createdBy;
  final String status; // 'active' | 'ended'
  final int memberCount;
  final DateTime? createdAt;

  const Ride({
    required this.id,
    required this.name,
    required this.code,
    this.destination,
    required this.createdBy,
    required this.status,
    required this.memberCount,
    this.createdAt,
  });

  bool isHost(String uid) => createdBy == uid;
  bool get isActive => status == 'active';
  String get destinationLabel => destination?.label ?? 'No destination set';

  Map<String, dynamic> toMap({bool isNew = false}) => <String, dynamic>{
        'name': name,
        'code': code,
        'destination': destination?.toMap(),
        'createdBy': createdBy,
        'status': status,
        'memberCount': memberCount,
        'createdAt': isNew ? FieldValue.serverTimestamp() : createdAt?.toUtc(),
      };

  factory Ride.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? const <String, dynamic>{};
    final dynamic dest = m['destination'];
    final dynamic ts = m['createdAt'];
    return Ride(
      id: doc.id,
      name: (m['name'] ?? '') as String,
      code: (m['code'] ?? '') as String,
      destination:
          dest is Map<String, dynamic> ? RideDestination.fromMap(dest) : null,
      createdBy: (m['createdBy'] ?? '') as String,
      status: (m['status'] ?? 'active') as String,
      memberCount: (m['memberCount'] ?? 0) as int,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  @override
  String toString() => 'Ride($id, $name, code $code)';
}
