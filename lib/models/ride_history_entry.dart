import 'package:cloud_firestore/cloud_firestore.dart';

/// A permanent record of a user having been part of a ride, stored at
/// `users/{uid}/rideHistory/{rideId}`.
///
/// Unlike `rideRefs` (which drives the live "My Rides" list and is deleted when
/// a user leaves), this entry is never removed — it is only status-patched to
/// `'left'` on leave — so a member's full ride history survives. `status` here
/// reflects the member's own relationship to the ride; a ride the host later
/// ends still reads `'active'`/`'left'` here (the ride doc holds the ended flag).
class RideHistoryEntry {
  final String rideId;
  final String name;
  final String role; // 'host' | 'rider'
  final String status; // 'active' | 'left'
  final DateTime? joinedAt;
  final DateTime? leftAt;

  const RideHistoryEntry({
    required this.rideId,
    required this.name,
    required this.role,
    required this.status,
    this.joinedAt,
    this.leftAt,
  });

  bool get isHost => role == 'host';
  bool get hasLeft => status == 'left';

  factory RideHistoryEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> m = doc.data() ?? const <String, dynamic>{};
    final dynamic j = m['joinedAt'];
    final dynamic l = m['leftAt'];
    return RideHistoryEntry(
      rideId: doc.id,
      name: (m['name'] ?? '') as String,
      role: (m['role'] ?? 'rider') as String,
      status: (m['status'] ?? 'active') as String,
      joinedAt: j is Timestamp ? j.toDate() : null,
      leftAt: l is Timestamp ? l.toDate() : null,
    );
  }
}
