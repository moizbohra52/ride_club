import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';

import '../core/utils/logger.dart';
import '../models/ride_memory.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// Firestore + Storage access for shared trip memories, stored at
/// `rides/{rideId}/memories/{memoryId}` with media under
/// `ride_memories/{rideId}/{memoryId}/…`.
///
/// A memory doc is created first (to allocate an id), media is uploaded under
/// that id, then the doc is patched with the resulting download URLs. Writes
/// are timeout-guarded so the UI never hangs (mirrors [RideService]).
class RideMemoryService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();

  static const Duration _timeout = Duration(seconds: 30);

  CollectionReference<Map<String, dynamic>> _memories(String rideId) =>
      _db.collection('rides').doc(rideId).collection('memories');

  /// All memories for a ride, newest first.
  Stream<List<RideMemory>> watch(String rideId) => _memories(rideId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> s) =>
          s.docs.map(RideMemory.fromDoc).toList());

  /// Create a memory and upload its media. [kind] is `'pin'` or `'log'`.
  /// Returns the new memory id. Media upload failures are non-fatal — the
  /// note/pin is still saved and a warning is surfaced by the caller.
  Future<String> addMemory({
    required String rideId,
    required String kind,
    required double lat,
    required double lng,
    String? title,
    String? note,
    List<File> photos = const <File>[],
    File? voice,
    int? voiceMs,
  }) async {
    final String? uid = _auth.uid;
    if (uid == null) throw Exception('You are not signed in.');
    final profile = await _users.fetch(uid);

    final DocumentReference<Map<String, dynamic>> ref = _memories(rideId).doc();

    // 1) Create the doc first so we have an id to key Storage paths on.
    final RideMemory base = RideMemory(
      id: ref.id,
      kind: kind,
      lat: lat,
      lng: lng,
      title: title?.trim().isEmpty ?? true ? null : title!.trim(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      authorId: uid,
      authorName: profile?.name ?? 'Rider',
      authorPhoto: profile?.photoUrl,
    );
    await ref.set(base.toMap(isNew: true)).timeout(
          _timeout,
          onTimeout: () =>
              throw Exception('Saving timed out. Check your connection.'),
        );

    // 2) Upload media under the memory id, then patch URLs onto the doc.
    final List<String> photoUrls = <String>[];
    for (int i = 0; i < photos.length; i++) {
      final String? url = await _uploadFile(
        'ride_memories/$rideId/${ref.id}/photo_$i.jpg',
        photos[i],
        'image/jpeg',
      );
      if (url != null) photoUrls.add(url);
    }

    String? voiceUrl;
    if (voice != null) {
      voiceUrl = await _uploadFile(
        'ride_memories/$rideId/${ref.id}/voice.m4a',
        voice,
        'audio/mp4',
      );
    }

    if (photoUrls.isNotEmpty || voiceUrl != null) {
      await ref.set(<String, dynamic>{
        if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
        if (voiceUrl != null) 'voiceUrl': voiceUrl,
        if (voiceUrl != null && voiceMs != null) 'voiceMs': voiceMs,
      }, SetOptions(merge: true)).timeout(_timeout);
    }

    return ref.id;
  }

  Future<String?> _uploadFile(
    String path,
    File file,
    String contentType,
  ) async {
    try {
      final Reference ref = _storage.ref(path);
      final Uint8List bytes = await file.readAsBytes();
      final TaskSnapshot snap = await ref
          .putData(bytes, SettableMetadata(contentType: contentType))
          .timeout(_timeout);
      return await snap.ref.getDownloadURL();
    } catch (e, s) {
      Log.e('memory media upload failed ($path)', error: e, stack: s);
      return null;
    }
  }

  /// Delete a memory: its Storage folder (best-effort) then the doc. Callers
  /// must gate this to the author or ride host; rules enforce it server-side.
  Future<void> deleteMemory(String rideId, String memoryId) async {
    // Best-effort media cleanup — list & delete everything under the folder.
    try {
      final ListResult res =
          await _storage.ref('ride_memories/$rideId/$memoryId').listAll();
      for (final Reference item in res.items) {
        await item.delete().catchError((_) {});
      }
    } catch (e, s) {
      Log.e('memory media cleanup failed', error: e, stack: s);
    }
    await _memories(rideId).doc(memoryId).delete().timeout(
          _timeout,
          onTimeout: () =>
              throw Exception('Delete timed out. Check your connection.'),
        );
  }
}
