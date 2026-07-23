import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// A shared trip memory stored at `rides/{rideId}/memories/{memoryId}`.
///
/// Two kinds:
///  - `pin` — a named place a rider dropped by long-pressing the map.
///  - `log` — a quick entry captured at the rider's own live GPS position.
///
/// Every memory can carry a [note], any number of [photoUrls], and one voice
/// clip ([voiceUrl] + [voiceMs]). All members of the ride can see it. Media
/// lives in Firebase Storage under `ride_memories/{rideId}/{memoryId}/…`.
class RideMemory {
  final String id;
  final String kind; // 'pin' | 'log'
  final double lat;
  final double lng;
  final String? title;
  final String? note;
  final List<String> photoUrls;
  final String? voiceUrl;
  final int? voiceMs;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final DateTime? createdAt;

  const RideMemory({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    this.title,
    this.note,
    this.photoUrls = const <String>[],
    this.voiceUrl,
    this.voiceMs,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    this.createdAt,
  });

  bool get isPin => kind == 'pin';
  bool get hasVoice => voiceUrl != null && voiceUrl!.isNotEmpty;
  bool get hasPhotos => photoUrls.isNotEmpty;
  LatLng get latLng => LatLng(lat, lng);

  /// True when the signed-in [uid] may delete this memory (its author or the
  /// ride host — the host check is supplied by the caller via [isHost]).
  bool canDelete(String? uid, {bool isHost = false}) =>
      uid != null && (authorId == uid || isHost);

  Map<String, dynamic> toMap({bool isNew = false}) => <String, dynamic>{
        'kind': kind,
        'lat': lat,
        'lng': lng,
        'title': title,
        'note': note,
        'photoUrls': photoUrls,
        'voiceUrl': voiceUrl,
        'voiceMs': voiceMs,
        'authorId': authorId,
        'authorName': authorName,
        'authorPhoto': authorPhoto,
        'createdAt': isNew ? FieldValue.serverTimestamp() : createdAt?.toUtc(),
      };

  factory RideMemory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> m = doc.data() ?? const <String, dynamic>{};
    final dynamic photos = m['photoUrls'];
    final dynamic ts = m['createdAt'];
    return RideMemory(
      id: doc.id,
      kind: (m['kind'] ?? 'pin') as String,
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      title: m['title'] as String?,
      note: m['note'] as String?,
      photoUrls: photos is List
          ? photos.whereType<String>().toList()
          : const <String>[],
      voiceUrl: m['voiceUrl'] as String?,
      voiceMs: (m['voiceMs'] as num?)?.toInt(),
      authorId: (m['authorId'] ?? '') as String,
      authorName: (m['authorName'] ?? 'Rider') as String,
      authorPhoto: m['authorPhoto'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  @override
  String toString() => 'RideMemory($id, $kind, by $authorName)';
}
