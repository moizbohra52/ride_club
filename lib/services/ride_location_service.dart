import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import '../models/member_location.dart';
import '../models/ride_position.dart';
import 'auth_service.dart';

/// Realtime Database read/write for live locations + presence.
///
/// Writes the local [RidePosition] stream to `locations/{rideId}/{uid}`, keeps
/// presence at `presence/{rideId}/{uid}` (with `onDisconnect` auto-offline),
/// and streams all members merged into [MemberLocation]s.
class RideLocationService extends GetxService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final AuthService _auth = Get.find<AuthService>();
  StreamSubscription<RidePosition>? _shareSub;

  DatabaseReference _loc(String rideId, String uid) =>
      _db.ref('locations/$rideId/$uid');
  DatabaseReference _pres(String rideId, String uid) =>
      _db.ref('presence/$rideId/$uid');

  void startSharing(String rideId, Stream<RidePosition> stream) {
    final String? uid = _auth.uid;
    if (uid == null) return;

    final DatabaseReference pres = _pres(rideId, uid);
    pres.set(<String, dynamic>{
      'online': true,
      'lastSeen': ServerValue.timestamp,
    });
    pres.onDisconnect().set(<String, dynamic>{
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });

    _shareSub?.cancel();
    _shareSub = stream.listen((RidePosition p) {
      final Map<String, dynamic> data = p.toRtdb()
        ..['updatedAt'] = ServerValue.timestamp;
      _loc(rideId, uid).set(data).catchError(
            (Object e) => Log.e('location write failed', error: e),
          );
    });
  }

  Future<void> stopSharing(String rideId) async {
    await _shareSub?.cancel();
    _shareSub = null;
    final String? uid = _auth.uid;
    if (uid == null) return;
    await _pres(rideId, uid).set(<String, dynamic>{
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Stream<List<MemberLocation>> watchLocations(String rideId) {
    final DatabaseReference locRef = _db.ref('locations/$rideId');
    final DatabaseReference presRef = _db.ref('presence/$rideId');
    return locRef.onValue.asyncMap((DatabaseEvent event) async {
      final Map<dynamic, dynamic> locs =
          (event.snapshot.value as Map<dynamic, dynamic>?) ??
              <dynamic, dynamic>{};
      final DataSnapshot presSnap = await presRef.get();
      final Map<dynamic, dynamic> pres =
          (presSnap.value as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
      return locs.entries.map((MapEntry<dynamic, dynamic> e) {
        return MemberLocation.fromMaps(
          e.key as String,
          e.value as Map<dynamic, dynamic>?,
          pres[e.key] as Map<dynamic, dynamic>?,
        );
      }).toList();
    });
  }
}
