import 'package:cloud_firestore/cloud_firestore.dart';

/// A RideTogether user profile, stored at Firestore `users/{uid}`.
///
/// A profile is considered "complete" once [name] is set (see [isComplete]),
/// which is what gates routing between profile-setup and home.
///
/// With Google sign-in, [email], [name], and [photoUrl] are seeded from the
/// Google account; [phone] is optional (Google accounts don't carry a phone).
class AppUser {
  final String uid;
  final String email;
  final String phone;
  final String name;
  final String? photoUrl;
  final String? emergencyContact;
  final String? fcmToken;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    this.email = '',
    this.phone = '',
    this.name = '',
    this.photoUrl,
    this.emergencyContact,
    this.fcmToken,
    this.createdAt,
  });

  bool get isComplete => name.trim().isNotEmpty;

  AppUser copyWith({
    String? uid,
    String? email,
    String? phone,
    String? name,
    String? photoUrl,
    String? emergencyContact,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Map for writing to Firestore. Uses [FieldValue.serverTimestamp] on first
  /// create so the server clock is authoritative.
  Map<String, dynamic> toMap({bool isNew = false}) {
    return <String, dynamic>{
      'uid': uid,
      'email': email,
      'phone': phone,
      'name': name,
      'photoUrl': photoUrl,
      'emergencyContact': emergencyContact,
      'fcmToken': fcmToken,
      'createdAt':
          isNew ? FieldValue.serverTimestamp() : createdAt?.toUtc(),
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic>? map) {
    final Map<String, dynamic> m = map ?? const <String, dynamic>{};
    final dynamic ts = m['createdAt'];
    return AppUser(
      uid: uid,
      email: (m['email'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      photoUrl: m['photoUrl'] as String?,
      emergencyContact: m['emergencyContact'] as String?,
      fcmToken: m['fcmToken'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.id, doc.data());

  @override
  String toString() =>
      'AppUser(uid: $uid, name: $name, email: $email, phone: $phone)';
}
