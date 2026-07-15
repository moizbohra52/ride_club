import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import '../models/app_user.dart';

/// Firestore + Storage access for the current user's profile (`users/{uid}`).
///
/// Reused by every later phase (rides read member names/photos from here).
class UserService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Fetch a profile once. Returns null if the doc doesn't exist.
  Future<AppUser?> fetch(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _users
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return AppUser.fromDoc(doc);
    } catch (e, s) {
      Log.e('UserService.fetch failed', error: e, stack: s);
      rethrow;
    }
  }

  /// Live profile stream (used when the profile can change elsewhere).
  Stream<AppUser?> watch(String uid) {
    return _users
        .doc(uid)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> d) =>
              d.exists ? AppUser.fromDoc(d) : null,
        );
  }

  /// Create or fully overwrite a profile document.
  ///
  /// Firestore's `set()` normally resolves against the local cache immediately
  /// and syncs in the background. If the backend is unreachable (e.g. the
  /// Firestore API isn't enabled yet) the write can hang, so we cap it with a
  /// timeout to keep the UI responsive and surface a clear error.
  Future<void> save(AppUser user, {bool isNew = false}) async {
    await _users
        .doc(user.uid)
        .set(user.toMap(isNew: isNew), SetOptions(merge: true))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Saving is taking too long. Check your connection and make sure '
            'Cloud Firestore is enabled for this project.',
          ),
        );
  }

  /// Patch specific fields (e.g. just the fcmToken).
  Future<void> update(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).set(fields, SetOptions(merge: true));
  }

  /// Upload a profile photo to `profile_photos/{uid}.jpg` and return its URL.
  Future<String> uploadProfilePhoto(String uid, File file) async {
    final Reference ref = _storage.ref("profile_photos/$uid.jpg");
    final Uint8List bytes = await file.readAsBytes();
    final UploadTask task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final TaskSnapshot snap = await task;
    return await snap.ref.getDownloadURL();
  }
}
