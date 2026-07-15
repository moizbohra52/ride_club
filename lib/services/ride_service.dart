import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/app_colors.dart';
import '../models/join_request.dart';
import '../models/ride.dart';
import '../models/ride_member.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// All ride Firestore access: create (with unique code), join requests, host
/// approval, and lifecycle. Writes are timeout-guarded so the UI never hangs
/// if the backend is unreachable.
class RideService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  final Random _rng = Random();

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const Duration _timeout = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _rides =>
      _db.collection('rides');

  CollectionReference<Map<String, dynamic>> _rideRefs(String uid) =>
      _db.collection('users').doc(uid).collection('rideRefs');

  /// A 6-char code from an unambiguous alphabet (no 0/O/1/I).
  String generateCode() => List<String>.generate(
    6,
    (_) => _alphabet[_rng.nextInt(_alphabet.length)],
  ).join();

  Future<String> _uniqueCode() async {
    for (int i = 0; i < 5; i++) {
      final String code = generateCode();
      final QuerySnapshot<Map<String, dynamic>> snap = await _rides
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return code;
    }
    throw Exception('Could not allocate a ride code. Please try again.');
  }

  Future<Ride> createRide({
    required String name,
    RideDestination? destination,
    RideDestination? origin,
    List<RideDestination> waypoints = const <RideDestination>[],
    List<LatLng>? plannedRoute,
    double? plannedDistanceMeters,
    double? plannedDurationSeconds,
  }) async {
    final String? uid = _auth.uid;
    if (uid == null) throw Exception('You are not signed in.');
    final profile = await _users.fetch(uid);
    final String code = await _uniqueCode();
    final DocumentReference<Map<String, dynamic>> rideRef = _rides.doc();

    final Ride ride = Ride(
      id: rideRef.id,
      name: name.trim(),
      code: code,
      destination: destination,
      origin: origin,
      waypoints: waypoints,
      plannedRoute: plannedRoute,
      plannedDistanceMeters: plannedDistanceMeters,
      plannedDurationSeconds: plannedDurationSeconds,
      createdBy: uid,
      status: 'active',
      memberCount: 1,
    );
    final RideMember host = RideMember(
      uid: uid,
      name: profile?.name ?? 'Host',
      photoUrl: profile?.photoUrl,
      colorValue: AppColors.memberColorForKey(uid).toARGB32(),
      role: 'host',
    );

    final WriteBatch batch = _db.batch();
    batch.set(rideRef, ride.toMap(isNew: true));
    batch.set(rideRef.collection('members').doc(uid), host.toMap(isNew: true));
    batch.set(_rideRefs(uid).doc(rideRef.id), <String, dynamic>{
      'rideId': rideRef.id,
      'name': name.trim(),
      'role': 'host',
      'status': 'active',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(
      _timeout,
      onTimeout: () => throw Exception(
        'Creating the ride timed out. Check your connection.',
      ),
    );
    return ride;
  }

  Stream<List<Ride>> watchMyRides() {
    final String? uid = _auth.uid;
    if (uid == null) return const Stream<List<Ride>>.empty();
    return _rideRefs(uid).snapshots().asyncMap((
      QuerySnapshot<Map<String, dynamic>> refs,
    ) async {
      final List<String> ids = refs.docs.map((d) => d.id).toList();
      if (ids.isEmpty) return <Ride>[];
      final List<Ride> rides = <Ride>[];
      for (final String id in ids) {
        final DocumentSnapshot<Map<String, dynamic>> doc = await _rides
            .doc(id)
            .get();
        if (doc.exists) rides.add(Ride.fromDoc(doc));
      }
      rides.sort(
        (Ride a, Ride b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
      return rides;
    });
  }

  Stream<Ride?> watchRide(String id) =>
      _rides.doc(id).snapshots().map((d) => d.exists ? Ride.fromDoc(d) : null);

  Stream<List<RideMember>> watchMembers(String id) => _rides
      .doc(id)
      .collection('members')
      .snapshots()
      .map((s) => s.docs.map(RideMember.fromDoc).toList());

  Stream<List<JoinRequest>> watchRequests(String id) => _rides
      .doc(id)
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(JoinRequest.fromDoc).toList());

  Stream<JoinRequest?> watchMyRequest(String rideId, String uid) => _rides
      .doc(rideId)
      .collection('requests')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? JoinRequest.fromDoc(d) : null);

  Future<Ride?> findByCode(String code) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _rides
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Ride.fromDoc(snap.docs.first);
  }

  Future<void> requestJoin(String code) async {
    final String? uid = _auth.uid;
    if (uid == null) throw Exception('You are not signed in.');
    final Ride? ride = await findByCode(code);
    if (ride == null) throw Exception('No ride found for that code.');
    if (!ride.isActive) throw Exception('That ride has ended.');
    if (ride.createdBy == uid)
      throw Exception('You are the host of this ride.');

    final DocumentSnapshot<Map<String, dynamic>> memberDoc = await _rides
        .doc(ride.id)
        .collection('members')
        .doc(uid)
        .get();
    if (memberDoc.exists) throw Exception('You are already in this ride.');

    final profile = await _users.fetch(uid);
    await _rides
        .doc(ride.id)
        .collection('requests')
        .doc(uid)
        .set(
          JoinRequest(
            uid: uid,
            name: profile?.name ?? 'Rider',
            photoUrl: profile?.photoUrl,
            status: 'pending',
          ).toMap(isNew: true),
        )
        .timeout(
          _timeout,
          onTimeout: () =>
              throw Exception('Request timed out. Check your connection.'),
        );
  }

  Future<void> acceptRequest(String rideId, JoinRequest req) async {
    final DocumentReference<Map<String, dynamic>> rideRef = _rides.doc(rideId);
    final RideMember member = RideMember(
      uid: req.uid,
      name: req.name,
      photoUrl: req.photoUrl,
      colorValue: AppColors.memberColorForKey(req.uid).toARGB32(),
      role: 'rider',
    );
    final WriteBatch batch = _db.batch();
    batch.set(
      rideRef.collection('members').doc(req.uid),
      member.toMap(isNew: true),
    );
    batch.update(rideRef.collection('requests').doc(req.uid), <String, dynamic>{
      'status': 'accepted',
    });
    batch.update(rideRef, <String, dynamic>{
      'memberCount': FieldValue.increment(1),
    });
    batch.set(_rideRefs(req.uid).doc(rideId), <String, dynamic>{
      'rideId': rideId,
      'name': req.name,
      'role': 'rider',
      'status': 'active',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(
      _timeout,
      onTimeout: () =>
          throw Exception('Accept timed out. Check your connection.'),
    );
  }

  Future<void> rejectRequest(String rideId, String uid) => _rides
      .doc(rideId)
      .collection('requests')
      .doc(uid)
      .update(<String, dynamic>{'status': 'rejected'})
      .timeout(_timeout, onTimeout: () => throw Exception('Reject timed out.'));

  Future<void> endRide(String rideId) => _rides
      .doc(rideId)
      .update(<String, dynamic>{'status': 'ended'})
      .timeout(
        _timeout,
        onTimeout: () => throw Exception('End ride timed out.'),
      );

  Future<void> leaveRide(String rideId) async {
    final String? uid = _auth.uid;
    if (uid == null) return;
    final DocumentReference<Map<String, dynamic>> rideRef = _rides.doc(rideId);
    final WriteBatch batch = _db.batch();
    batch.delete(rideRef.collection('members').doc(uid));
    batch.update(rideRef, <String, dynamic>{
      'memberCount': FieldValue.increment(-1),
    });
    batch.delete(_rideRefs(uid).doc(rideId));
    await batch.commit().timeout(
      _timeout,
      onTimeout: () => throw Exception('Leave timed out.'),
    );
  }
}
