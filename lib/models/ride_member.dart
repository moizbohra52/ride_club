import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// A member of a ride, stored at `rides/{rideId}/members/{uid}`. The color is
/// stored as an int so it survives Firestore round-trips and drives the map
/// marker (Phase 3).
class RideMember {
  final String uid;
  final String name;
  final String? photoUrl;
  final int colorValue;
  final String role; // 'host' | 'rider'
  final DateTime? joinedAt;

  const RideMember({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.colorValue,
    required this.role,
    this.joinedAt,
  });

  bool get isHost => role == 'host';
  Color get color => Color(colorValue);

  Map<String, dynamic> toMap({bool isNew = false}) => <String, dynamic>{
        'name': name,
        'photoUrl': photoUrl,
        'colorValue': colorValue,
        'role': role,
        'joinedAt': isNew ? FieldValue.serverTimestamp() : joinedAt?.toUtc(),
      };

  factory RideMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? const <String, dynamic>{};
    final dynamic ts = m['joinedAt'];
    return RideMember(
      uid: doc.id,
      name: (m['name'] ?? '') as String,
      photoUrl: m['photoUrl'] as String?,
      colorValue:
          (m['colorValue'] ?? AppColors.memberColors.first.toARGB32()) as int,
      role: (m['role'] ?? 'rider') as String,
      joinedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
