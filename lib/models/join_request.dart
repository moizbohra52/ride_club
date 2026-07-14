import 'package:cloud_firestore/cloud_firestore.dart';

/// A request to join a ride, stored at `rides/{rideId}/requests/{uid}`.
/// The host moves it from 'pending' to 'accepted' or 'rejected'.
class JoinRequest {
  final String uid;
  final String name;
  final String? photoUrl;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime? requestedAt;

  const JoinRequest({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.status,
    this.requestedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toMap({bool isNew = false}) => <String, dynamic>{
        'name': name,
        'photoUrl': photoUrl,
        'status': status,
        'requestedAt':
            isNew ? FieldValue.serverTimestamp() : requestedAt?.toUtc(),
      };

  factory JoinRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? const <String, dynamic>{};
    final dynamic ts = m['requestedAt'];
    return JoinRequest(
      uid: doc.id,
      name: (m['name'] ?? '') as String,
      photoUrl: m['photoUrl'] as String?,
      status: (m['status'] ?? 'pending') as String,
      requestedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
