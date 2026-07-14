# Phase 2 — Rides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let users create rides (with a Nominatim destination), share a 6-char code, request to join others' rides, and have hosts approve/reject — all wired to Firestore, surfaced through a My Rides / Create / Join tab shell.

**Architecture:** Two new GetxService singletons (`RideService` for Firestore ride CRUD + code generation, `GeoService` for Nominatim). Four models (`Ride`, `RideMember`, `JoinRequest`, `PlaceResult`). A `modules/rides/` module with a bottom-tab shell hosting My Rides, Create, Join, plus a Ride Detail screen. Denormalized `users/{uid}/rideRefs` for fast "my rides".

**Tech Stack:** Flutter, GetX, cloud_firestore, http (Nominatim), share_plus, existing Phase 1 theme/widgets.

## Global Constraints

- Null-safety; Material 3; GetX for state/routing/DI (no substitution).
- Firestore writes wrapped with `.timeout(Duration(seconds: 15))` → friendly error (Phase 1 pattern in `UserService.save`).
- Nominatim requests MUST send `User-Agent: AppConstants.httpUserAgent`; debounce search input ≥500ms; never spam (OSM policy).
- Ride code alphabet: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no 0/O/1/I), length `AppConstants.rideCodeLength` (6).
- Every module folder: `<name>_view.dart`, `<name>_controller.dart`, `<name>_binding.dart`.
- Typed friendly errors via `UiHelpers`; handle no-internet, timeout, empty states.
- `flutter analyze` must pass with no issues after each task.
- Member colors from `AppColors.memberColorForKey(uid)`.

---

### Task 1: Models — Ride, RideMember, JoinRequest, PlaceResult

**Files:**
- Create: `lib/models/ride.dart`, `lib/models/ride_member.dart`, `lib/models/join_request.dart`, `lib/models/place_result.dart`
- Test: `test/models_test.dart`

**Interfaces:**
- Produces:
  - `Ride{ id, name, code, destination: RideDestination?, createdBy, status ('active'|'ended'), memberCount, createdAt }`; `Ride.fromDoc(doc)`, `toMap({isNew})`, `bool isHost(String uid)`, `String get destinationLabel`.
  - `RideDestination{ lat: double, lng: double, label: String }`; `fromMap`/`toMap`.
  - `RideMember{ uid, name, photoUrl?, colorValue: int, role ('host'|'rider'), joinedAt? }`; `fromDoc`, `toMap`, `Color get color`.
  - `JoinRequest{ uid, name, photoUrl?, status ('pending'|'accepted'|'rejected'), requestedAt? }`; `fromDoc`, `toMap`.
  - `PlaceResult{ lat: double, lng: double, displayName: String }`; `fromJson(Map)`.

- [ ] **Step 1: Write failing tests**

```dart
// test/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/models/ride.dart';
import 'package:ride_club/models/place_result.dart';

void main() {
  test('Ride.isHost true for creator', () {
    final r = Ride(id: 'r1', name: 'Trip', code: 'ABC123', createdBy: 'u1',
        status: 'active', memberCount: 1);
    expect(r.isHost('u1'), isTrue);
    expect(r.isHost('u2'), isFalse);
  });

  test('Ride.destinationLabel falls back when null', () {
    final r = Ride(id: 'r1', name: 'Trip', code: 'ABC123', createdBy: 'u1',
        status: 'active', memberCount: 1);
    expect(r.destinationLabel, 'No destination set');
  });

  test('PlaceResult.fromJson parses Nominatim shape', () {
    final p = PlaceResult.fromJson(<String, dynamic>{
      'lat': '30.12', 'lon': '78.45', 'display_name': 'Rishikesh, India',
    });
    expect(p.lat, closeTo(30.12, 0.001));
    expect(p.lng, closeTo(78.45, 0.001));
    expect(p.displayName, 'Rishikesh, India');
  });
}
```

- [ ] **Step 2: Run test — expect FAIL** (`flutter test test/models_test.dart`) — "Target of URI doesn't exist".

- [ ] **Step 3: Implement models**

```dart
// lib/models/ride.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RideDestination {
  final double lat;
  final double lng;
  final String label;
  const RideDestination({required this.lat, required this.lng, required this.label});

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'label': label};

  factory RideDestination.fromMap(Map<String, dynamic> m) => RideDestination(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        label: (m['label'] ?? '') as String,
      );
}

class Ride {
  final String id;
  final String name;
  final String code;
  final RideDestination? destination;
  final String createdBy;
  final String status;
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

  Map<String, dynamic> toMap({bool isNew = false}) => {
        'name': name,
        'code': code,
        'destination': destination?.toMap(),
        'createdBy': createdBy,
        'status': status,
        'memberCount': memberCount,
        'createdAt': isNew ? FieldValue.serverTimestamp() : createdAt?.toUtc(),
      };

  factory Ride.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    final dest = m['destination'];
    final ts = m['createdAt'];
    return Ride(
      id: doc.id,
      name: (m['name'] ?? '') as String,
      code: (m['code'] ?? '') as String,
      destination: dest is Map<String, dynamic>
          ? RideDestination.fromMap(dest)
          : null,
      createdBy: (m['createdBy'] ?? '') as String,
      status: (m['status'] ?? 'active') as String,
      memberCount: (m['memberCount'] ?? 0) as int,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
```

```dart
// lib/models/ride_member.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

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

  Map<String, dynamic> toMap({bool isNew = false}) => {
        'name': name,
        'photoUrl': photoUrl,
        'colorValue': colorValue,
        'role': role,
        'joinedAt': isNew ? FieldValue.serverTimestamp() : joinedAt?.toUtc(),
      };

  factory RideMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    final ts = m['joinedAt'];
    return RideMember(
      uid: doc.id,
      name: (m['name'] ?? '') as String,
      photoUrl: m['photoUrl'] as String?,
      colorValue: (m['colorValue'] ?? AppColors.memberColors.first.toARGB32())
          as int,
      role: (m['role'] ?? 'rider') as String,
      joinedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
```

```dart
// lib/models/join_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toMap({bool isNew = false}) => {
        'name': name,
        'photoUrl': photoUrl,
        'status': status,
        'requestedAt': isNew ? FieldValue.serverTimestamp() : requestedAt?.toUtc(),
      };

  factory JoinRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    final ts = m['requestedAt'];
    return JoinRequest(
      uid: doc.id,
      name: (m['name'] ?? '') as String,
      photoUrl: m['photoUrl'] as String?,
      status: (m['status'] ?? 'pending') as String,
      requestedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
```

```dart
// lib/models/place_result.dart
class PlaceResult {
  final double lat;
  final double lng;
  final String displayName;
  const PlaceResult({required this.lat, required this.lng, required this.displayName});

  factory PlaceResult.fromJson(Map<String, dynamic> j) => PlaceResult(
        lat: double.parse(j['lat'].toString()),
        lng: double.parse(j['lon'].toString()),
        displayName: (j['display_name'] ?? '') as String,
      );
}
```

- [ ] **Step 4: Run test — expect PASS** (`flutter test test/models_test.dart`).
- [ ] **Step 5: `flutter analyze` clean, then commit** `feat(phase2): ride/member/request/place models`.

---

### Task 2: GeoService — Nominatim search

**Files:**
- Create: `lib/services/geo_service.dart`
- Test: `test/geo_service_test.dart`

**Interfaces:**
- Consumes: `PlaceResult` (Task 1), `AppConstants.nominatimBaseUrl`, `AppConstants.httpUserAgent`, `AppConstants.networkTimeout`.
- Produces: `GeoService extends GetxService` with `Future<List<PlaceResult>> searchPlaces(String query, {http.Client? client})`. Returns `[]` for queries shorter than 3 chars. Parses a JSON array of Nominatim results.

- [ ] **Step 1: Write failing test** (inject a mock client so no real network call)

```dart
// test/geo_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ride_club/services/geo_service.dart';

void main() {
  test('searchPlaces parses Nominatim array', () async {
    final mock = MockClient((req) async {
      expect(req.headers['User-Agent'], isNotEmpty);
      return http.Response(
        '[{"lat":"30.12","lon":"78.45","display_name":"Rishikesh"}]', 200);
    });
    final svc = GeoService();
    final res = await svc.searchPlaces('Rishikesh', client: mock);
    expect(res, hasLength(1));
    expect(res.first.displayName, 'Rishikesh');
  });

  test('searchPlaces returns empty for short query', () async {
    final svc = GeoService();
    expect(await svc.searchPlaces('ab'), isEmpty);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`flutter test test/geo_service_test.dart`).

- [ ] **Step 3: Implement**

```dart
// lib/services/geo_service.dart
import 'dart:convert';
import 'package:get/get.dart' hide Response;
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../models/place_result.dart';

/// Nominatim geocoding search. Sends the OSM-required User-Agent and returns
/// place candidates for a free-text query. Keep calls infrequent (the caller
/// debounces) to respect OSM's usage policy.
class GeoService extends GetxService {
  Future<List<PlaceResult>> searchPlaces(String query, {http.Client? client}) async {
    final q = query.trim();
    if (q.length < 3) return <PlaceResult>[];
    final http.Client c = client ?? http.Client();
    try {
      final uri = Uri.parse('${AppConstants.nominatimBaseUrl}/search').replace(
        queryParameters: <String, String>{
          'q': q,
          'format': 'json',
          'limit': '6',
          'addressdetails': '0',
        },
      );
      final res = await c
          .get(uri, headers: {'User-Agent': AppConstants.httpUserAgent})
          .timeout(AppConstants.networkTimeout);
      if (res.statusCode != 200) return <PlaceResult>[];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      Log.e('Nominatim search failed', error: e, stack: s);
      return <PlaceResult>[];
    } finally {
      if (client == null) c.close();
    }
  }
}
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: analyze clean; commit** `feat(phase2): GeoService Nominatim search`.

---

### Task 3: RideService — code generation + createRide (batch)

**Files:**
- Create: `lib/services/ride_service.dart`
- Test: `test/ride_service_test.dart` (test the pure code generator only; Firestore methods verified on-device)

**Interfaces:**
- Consumes: `Ride`, `RideMember`, `RideDestination` (Task 1), `AuthService`, `UserService` (Phase 1), `AppColors`.
- Produces: `RideService extends GetxService` with:
  - `String generateCode()` — 6 chars from the allowed alphabet (uses `Random`).
  - `Future<Ride> createRide({required String name, RideDestination? destination})` — generates a unique code (retry 5×), batch-writes `rides/{id}` + `members/{host}` + `users/{host}/rideRefs/{id}`, returns the created `Ride`.
  - Stream getters used by later tasks: `Stream<List<Ride>> watchMyRides()`, `Stream<Ride?> watchRide(String id)`, `Stream<List<RideMember>> watchMembers(String id)`.

- [ ] **Step 1: Write failing test (code generator is pure)**

```dart
// test/ride_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/services/ride_service.dart';

void main() {
  test('generateCode is 6 chars from allowed alphabet', () {
    final svc = RideService();
    const allowed = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for (var i = 0; i < 50; i++) {
      final code = svc.generateCode();
      expect(code.length, 6);
      for (final ch in code.split('')) {
        expect(allowed.contains(ch), isTrue, reason: 'bad char $ch');
      }
    }
  });
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement RideService**

```dart
// lib/services/ride_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../core/theme/app_colors.dart';
import '../models/ride.dart';
import '../models/ride_member.dart';
import '../models/join_request.dart';
import 'auth_service.dart';
import 'user_service.dart';

class RideService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  final Random _rng = Random();

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const Duration _timeout = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _rides => _db.collection('rides');

  String generateCode() =>
      List.generate(6, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();

  Future<String> _uniqueCode() async {
    for (var i = 0; i < 5; i++) {
      final code = generateCode();
      final snap = await _rides.where('code', isEqualTo: code).limit(1).get();
      if (snap.docs.isEmpty) return code;
    }
    throw Exception('Could not allocate a ride code. Please try again.');
  }

  Future<Ride> createRide({required String name, RideDestination? destination}) async {
    final uid = _auth.uid;
    if (uid == null) throw Exception('You are not signed in.');
    final profile = await _users.fetch(uid);
    final code = await _uniqueCode();
    final rideRef = _rides.doc();

    final ride = Ride(
      id: rideRef.id, name: name.trim(), code: code, destination: destination,
      createdBy: uid, status: 'active', memberCount: 1,
    );
    final member = RideMember(
      uid: uid, name: profile?.name ?? 'Host', photoUrl: profile?.photoUrl,
      colorValue: AppColors.memberColorForKey(uid).toARGB32(), role: 'host',
    );

    final batch = _db.batch();
    batch.set(rideRef, ride.toMap(isNew: true));
    batch.set(rideRef.collection('members').doc(uid), member.toMap(isNew: true));
    batch.set(_db.collection('users').doc(uid).collection('rideRefs').doc(rideRef.id), {
      'rideId': rideRef.id, 'name': name.trim(), 'role': 'host',
      'status': 'active', 'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(_timeout,
        onTimeout: () => throw Exception('Creating the ride timed out. Check your connection.'));
    return ride;
  }

  Stream<List<Ride>> watchMyRides() {
    final uid = _auth.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).collection('rideRefs')
        .snapshots()
        .asyncMap((refs) async {
      final ids = refs.docs.map((d) => d.id).toList();
      if (ids.isEmpty) return <Ride>[];
      // Fetch each referenced ride doc (small N; fine for Spark).
      final rides = <Ride>[];
      for (final id in ids) {
        final doc = await _rides.doc(id).get();
        if (doc.exists) rides.add(Ride.fromDoc(doc));
      }
      rides.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return rides;
    });
  }

  Stream<Ride?> watchRide(String id) =>
      _rides.doc(id).snapshots().map((d) => d.exists ? Ride.fromDoc(d) : null);

  Stream<List<RideMember>> watchMembers(String id) => _rides.doc(id)
      .collection('members').snapshots()
      .map((s) => s.docs.map(RideMember.fromDoc).toList());

  // --- join / approval (Task 4 uses these) ---
  Stream<List<JoinRequest>> watchRequests(String id) => _rides.doc(id)
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(JoinRequest.fromDoc).toList());

  Stream<JoinRequest?> watchMyRequest(String rideId, String uid) => _rides
      .doc(rideId).collection('requests').doc(uid).snapshots()
      .map((d) => d.exists ? JoinRequest.fromDoc(d) : null);

  /// Find a ride by code. Returns null if not found.
  Future<Ride?> findByCode(String code) async {
    final snap = await _rides.where('code', isEqualTo: code.toUpperCase())
        .limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Ride.fromDoc(snap.docs.first);
  }

  Future<void> requestJoin(String code) async {
    final uid = _auth.uid;
    if (uid == null) throw Exception('You are not signed in.');
    final ride = await findByCode(code);
    if (ride == null) throw Exception('No ride found for that code.');
    if (!ride.isActive) throw Exception('That ride has ended.');
    if (ride.createdBy == uid) throw Exception('You are the host of this ride.');

    final memberDoc = await _rides.doc(ride.id).collection('members').doc(uid).get();
    if (memberDoc.exists) throw Exception('You are already in this ride.');

    final profile = await _users.fetch(uid);
    await _rides.doc(ride.id).collection('requests').doc(uid).set(
      JoinRequest(uid: uid, name: profile?.name ?? 'Rider',
          photoUrl: profile?.photoUrl, status: 'pending').toMap(isNew: true),
    ).timeout(_timeout,
        onTimeout: () => throw Exception('Request timed out. Check your connection.'));
  }

  Future<void> acceptRequest(String rideId, JoinRequest req) async {
    final rideRef = _rides.doc(rideId);
    final member = RideMember(
      uid: req.uid, name: req.name, photoUrl: req.photoUrl,
      colorValue: AppColors.memberColorForKey(req.uid).toARGB32(), role: 'rider',
    );
    final batch = _db.batch();
    batch.set(rideRef.collection('members').doc(req.uid), member.toMap(isNew: true));
    batch.update(rideRef.collection('requests').doc(req.uid), {'status': 'accepted'});
    batch.update(rideRef, {'memberCount': FieldValue.increment(1)});
    batch.set(_db.collection('users').doc(req.uid).collection('rideRefs').doc(rideId), {
      'rideId': rideId, 'name': req.name, 'role': 'rider',
      'status': 'active', 'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(_timeout,
        onTimeout: () => throw Exception('Accept timed out. Check your connection.'));
  }

  Future<void> rejectRequest(String rideId, String uid) => _rides.doc(rideId)
      .collection('requests').doc(uid).update({'status': 'rejected'})
      .timeout(_timeout,
          onTimeout: () => throw Exception('Reject timed out.'));

  Future<void> endRide(String rideId) async {
    await _rides.doc(rideId).update({'status': 'ended'}).timeout(_timeout,
        onTimeout: () => throw Exception('End ride timed out.'));
  }

  Future<void> leaveRide(String rideId) async {
    final uid = _auth.uid;
    if (uid == null) return;
    final rideRef = _rides.doc(rideId);
    final batch = _db.batch();
    batch.delete(rideRef.collection('members').doc(uid));
    batch.update(rideRef, {'memberCount': FieldValue.increment(-1)});
    batch.delete(_db.collection('users').doc(uid).collection('rideRefs').doc(rideId));
    await batch.commit().timeout(_timeout,
        onTimeout: () => throw Exception('Leave timed out.'));
  }
}
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: register in `main.dart`** — after `Get.put<UserService>...`, add `Get.put<RideService>(RideService(), permanent: true);` and `Get.put<GeoService>(GeoService(), permanent: true);` (import both).
- [ ] **Step 6: analyze clean; commit** `feat(phase2): RideService (create/join/approve/end) + register services`.

---

### Task 4: Rides shell + My Rides tab

**Files:**
- Create: `lib/modules/rides/rides_shell_view.dart`, `rides_shell_controller.dart`, `rides_shell_binding.dart`
- Create: `lib/modules/rides/my_rides_tab.dart`
- Modify: `lib/routes/app_pages.dart` (point `Routes.home` at `RidesShellView` + `RidesShellBinding`; remove old HomeView/HomeBinding import), `lib/routes/app_routes.dart` (add `rideDetail`).

**Interfaces:**
- Consumes: `RideService.watchMyRides()` (Task 3), `ThemeService`, `AuthService`.
- Produces: `RidesShellController` with `RxInt tabIndex`, `Rx<List<Ride>> myRides` bound to the stream; `RidesShellView` = Scaffold + NavigationBar (3 destinations) switching between `MyRidesTab`, `CreateRideTab` (Task 5), `JoinRideTab` (Task 6).

- [ ] **Step 1: Controller**

```dart
// lib/modules/rides/rides_shell_controller.dart
import 'package:get/get.dart';
import '../../models/ride.dart';
import '../../services/ride_service.dart';

class RidesShellController extends GetxController {
  final RideService _rides = Get.find<RideService>();
  final RxInt tabIndex = 0.obs;
  final RxList<Ride> myRides = <Ride>[].obs;
  final RxBool loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    myRides.bindStream(_rides.watchMyRides());
    ever(myRides, (_) => loading.value = false);
  }
}
```

- [ ] **Step 2: Binding**

```dart
// lib/modules/rides/rides_shell_binding.dart
import 'package:get/get.dart';
import 'rides_shell_controller.dart';

class RidesShellBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<RidesShellController>(() => RidesShellController());
}
```

- [ ] **Step 3: My Rides tab** (uses gradient cards consistent with the redesigned home)

```dart
// lib/modules/rides/my_rides_tab.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import 'rides_shell_controller.dart';

class MyRidesTab extends StatelessWidget {
  const MyRidesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RidesShellController>();
    final scheme = Theme.of(context).colorScheme;
    final uid = Get.find<AuthService>().uid;
    return Obx(() {
      if (c.loading.value) return const Center(child: CircularProgressIndicator());
      if (c.myRides.isEmpty) {
        return _empty(context, scheme);
      }
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: c.myRides.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final Ride r = c.myRides[i];
          final host = uid != null && r.isHost(uid);
          return _RideCard(ride: r, isHost: host);
        },
      );
    });
  }

  Widget _empty(BuildContext context, ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.route_rounded, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('No rides yet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Create a ride or join one with a code to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ]),
        ),
      );
}

class _RideCard extends StatelessWidget {
  final Ride ride;
  final bool isHost;
  const _RideCard({required this.ride, required this.isHost});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Get.toNamed(Routes.rideDetail, arguments: ride.id),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              height: 46, width: 46,
              decoration: BoxDecoration(
                gradient: isHost ? AppColors.horizon : null,
                color: isHost ? null : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isHost ? Icons.star_rounded : Icons.group_rounded,
                  color: isHost ? Colors.white : scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ride.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${isHost ? 'Host' : 'Rider'} · Code ${ride.code}'
                    '${ride.isActive ? '' : ' · Ended'}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Shell view**

```dart
// lib/modules/rides/rides_shell_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'create_ride_tab.dart';
import 'join_ride_tab.dart';
import 'my_rides_tab.dart';
import 'rides_shell_controller.dart';

class RidesShellView extends GetView<RidesShellController> {
  const RidesShellView({super.key});

  @override
  Widget build(BuildContext context) {
    const titles = ['My Rides', 'Create a ride', 'Join a ride'];
    return Obx(() => Scaffold(
          appBar: AppBar(title: Text(titles[controller.tabIndex.value])),
          body: IndexedStack(
            index: controller.tabIndex.value,
            children: const [MyRidesTab(), CreateRideTab(), JoinRideTab()],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: controller.tabIndex.value,
            onDestinationSelected: (i) => controller.tabIndex.value = i,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.route_outlined),
                  selectedIcon: Icon(Icons.route_rounded), label: 'My Rides'),
              NavigationDestination(icon: Icon(Icons.add_road_outlined),
                  selectedIcon: Icon(Icons.add_road_rounded), label: 'Create'),
              NavigationDestination(icon: Icon(Icons.group_add_outlined),
                  selectedIcon: Icon(Icons.group_add_rounded), label: 'Join'),
            ],
          ),
        ));
  }
}
```

- [ ] **Step 5: Routes** — in `app_routes.dart` keep `home`; add `static const String rideDetail = '/ride-detail';`. In `app_pages.dart` replace the home page entry:

```dart
// remove: import '../modules/home/home_binding.dart'; import '../modules/home/home_view.dart';
import '../modules/rides/rides_shell_binding.dart';
import '../modules/rides/rides_shell_view.dart';
import '../modules/rides/ride_detail_binding.dart';
import '../modules/rides/ride_detail_view.dart';
// ...
GetPage<dynamic>(name: Routes.home, page: () => const RidesShellView(),
    binding: RidesShellBinding(), transition: Transition.fadeIn),
GetPage<dynamic>(name: Routes.rideDetail, page: () => const RideDetailView(),
    binding: RideDetailBinding(), transition: Transition.rightToLeft),
```

(Note: `CreateRideTab`, `JoinRideTab`, `RideDetailView/Binding` come in Tasks 5–7; the app won't compile until those exist. Build Tasks 5–7 before running. Keep the old `modules/home/` files until Task 7, then delete.)

- [ ] **Step 6: commit** `feat(phase2): rides shell + my rides tab + routes` (defer analyze to Task 7 since tabs are stubs until then).

---

### Task 5: Create Ride tab (with Nominatim destination search)

**Files:**
- Create: `lib/modules/rides/create_ride_tab.dart`, `lib/modules/rides/create_ride_controller.dart`

**Interfaces:**
- Consumes: `GeoService.searchPlaces` (Task 2), `RideService.createRide` (Task 3), `RideDestination`, `PlaceResult`, `UiHelpers`, `PrimaryButton`, `share_plus`.
- Produces: `CreateRideController` with `nameField`, `RxList<PlaceResult> suggestions`, `Rxn<PlaceResult> chosen`, `RxBool creating`, debounced `onSearchChanged(q)`, `create()`. `CreateRideTab` widget.

- [ ] **Step 1: Controller** (debounced search, create, share)

```dart
// lib/modules/rides/create_ride_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/place_result.dart';
import '../../models/ride.dart';
import '../../services/geo_service.dart';
import '../../services/ride_service.dart';
import 'rides_shell_controller.dart';

class CreateRideController extends GetxController {
  final GeoService _geo = Get.find<GeoService>();
  final RideService _rides = Get.find<RideService>();

  final TextEditingController nameField = TextEditingController();
  final TextEditingController destField = TextEditingController();
  final RxList<PlaceResult> suggestions = <PlaceResult>[].obs;
  final Rxn<PlaceResult> chosen = Rxn<PlaceResult>();
  final RxBool searching = false.obs;
  final RxBool creating = false.obs;
  Timer? _debounce;

  void onSearchChanged(String q) {
    chosen.value = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 550), () async {
      searching.value = true;
      suggestions.value = await _geo.searchPlaces(q);
      searching.value = false;
    });
  }

  void choose(PlaceResult p) {
    chosen.value = p;
    destField.text = p.displayName;
    suggestions.clear();
  }

  Future<void> create() async {
    if (nameField.text.trim().isEmpty) {
      UiHelpers.error('Give your ride a name.');
      return;
    }
    creating.value = true;
    try {
      final RideDestination? dest = chosen.value == null
          ? null
          : RideDestination(
              lat: chosen.value!.lat, lng: chosen.value!.lng,
              label: chosen.value!.displayName);
      final Ride ride = await _rides.createRide(
          name: nameField.text, destination: dest);
      _showCreated(ride);
      nameField.clear();
      destField.clear();
      chosen.value = null;
      // jump to My Rides tab
      Get.find<RidesShellController>().tabIndex.value = 0;
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      creating.value = false;
    }
  }

  void _showCreated(Ride ride) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 44),
          const SizedBox(height: 12),
          const Text('Ride created!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 8),
          const Text('Share this code with your crew:'),
          const SizedBox(height: 12),
          SelectableText(ride.code,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 6)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(ShareParams(
              text: 'Join my RideTogether ride "${ride.name}" with code: ${ride.code}',
            )),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share code'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Get.back(), child: const Text('Done')),
        ]),
      ),
      isScrollControlled: true,
    );
  }

  @override
  void onClose() {
    _debounce?.cancel();
    nameField.dispose();
    destField.dispose();
    super.onClose();
  }
}
```

- [ ] **Step 2: View**

```dart
// lib/modules/rides/create_ride_tab.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'create_ride_controller.dart';

class CreateRideTab extends StatelessWidget {
  const CreateRideTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CreateRideController());
    final scheme = Theme.of(context).colorScheme;
    return Obx(() => LoadingOverlay(
          isLoading: c.creating.value,
          message: 'Creating ride…',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: c.nameField,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Ride name', hintText: 'Weekend to Lonavala',
                    prefixIcon: Icon(Icons.edit_road_rounded)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: c.destField,
                onChanged: c.onSearchChanged,
                decoration: InputDecoration(
                  labelText: 'Destination (optional)',
                  hintText: 'Search a place',
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: c.searching.value
                      ? const Padding(padding: EdgeInsets.all(12),
                          child: SizedBox(height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              ...c.suggestions.map((p) => ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(p.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => c.choose(p),
                  )),
              if (c.chosen.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: scheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Destination set',
                        style: TextStyle(color: scheme.primary))),
                  ]),
                ),
              const SizedBox(height: 28),
              PrimaryButton(
                  label: 'Create ride',
                  icon: Icons.add_road_rounded,
                  onPressed: c.create),
            ]),
          ),
        ));
  }
}
```

- [ ] **Step 3: commit** `feat(phase2): create ride tab with Nominatim search + share`.

---

### Task 6: Join Ride tab (request + live status)

**Files:**
- Create: `lib/modules/rides/join_ride_tab.dart`, `lib/modules/rides/join_ride_controller.dart`

**Interfaces:**
- Consumes: `RideService.requestJoin`, `RideService.findByCode`, `RideService.watchMyRequest` (Task 3), `AuthService`, `pin_code_fields`, `UiHelpers`.
- Produces: `JoinRideController` with `RxString code`, `RxBool submitting`, `Rxn<JoinRequest> myRequest`, `Rxn<String> pendingRideId`, `submit()`. `JoinRideTab` widget showing form → pending/accepted/rejected states.

- [ ] **Step 1: Controller**

```dart
// lib/modules/rides/join_ride_controller.dart
import 'package:get/get.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/join_request.dart';
import '../../models/ride.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';

class JoinRideController extends GetxController {
  final RideService _rides = Get.find<RideService>();
  final AuthService _auth = Get.find<AuthService>();

  final RxString code = ''.obs;
  final RxBool submitting = false.obs;
  final Rxn<JoinRequest> myRequest = Rxn<JoinRequest>();
  final Rxn<Ride> targetRide = Rxn<Ride>();

  Future<void> submit() async {
    if (code.value.length != 6) {
      UiHelpers.error('Enter the full 6-character code.');
      return;
    }
    submitting.value = true;
    try {
      final Ride? ride = await _rides.findByCode(code.value);
      if (ride == null) throw Exception('No ride found for that code.');
      await _rides.requestJoin(code.value);
      targetRide.value = ride;
      // watch our own request so the UI reflects accept/reject live
      final uid = _auth.uid!;
      myRequest.bindStream(_rides.watchMyRequest(ride.id, uid));
      UiHelpers.success('Request sent. Waiting for the host to approve.');
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      submitting.value = false;
    }
  }

  void openRide() {
    final id = targetRide.value?.id;
    if (id != null) Get.toNamed(Routes.rideDetail, arguments: id);
  }

  void reset() {
    myRequest.value = null;
    targetRide.value = null;
    code.value = '';
  }
}
```

- [ ] **Step 2: View**

```dart
// lib/modules/rides/join_ride_tab.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'join_ride_controller.dart';

class JoinRideTab extends StatelessWidget {
  const JoinRideTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(JoinRideController());
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final req = c.myRequest.value;
      if (req != null) return _statusView(context, c, scheme);
      return LoadingOverlay(
        isLoading: c.submitting.value,
        message: 'Sending request…',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            Text('Enter ride code',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Ask the host for their 6-character code.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            PinCodeTextField(
              appContext: context,
              length: 6,
              autoFocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) => c.code.value = v.toUpperCase(),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 54, fieldWidth: 44,
                activeColor: scheme.primary, selectedColor: scheme.primary,
                inactiveColor: scheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Request to join',
                icon: Icons.group_add_rounded, onPressed: c.submit),
          ]),
        ),
      );
    });
  }

  Widget _statusView(BuildContext ctx, JoinRideController c, ColorScheme scheme) {
    final req = c.myRequest.value!;
    late final IconData icon; late final String title; late final String sub;
    if (req.isAccepted) {
      icon = Icons.check_circle_rounded; title = 'You\'re in!';
      sub = 'The host accepted your request.';
    } else if (req.isRejected) {
      icon = Icons.cancel_rounded; title = 'Request declined';
      sub = 'The host declined this request.';
    } else {
      icon = Icons.hourglass_top_rounded; title = 'Waiting for approval';
      sub = 'The host will see your request and let you in.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(sub, textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          if (req.isAccepted)
            PrimaryButton(label: 'Open ride',
                icon: Icons.arrow_forward_rounded, onPressed: c.openRide),
          if (req.isRejected || req.isAccepted)
            TextButton(onPressed: c.reset, child: const Text('Join a different ride')),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 3: commit** `feat(phase2): join ride tab with live request status`.

---

### Task 7: Ride Detail (members, share, host approval, end/leave) + cleanup

**Files:**
- Create: `lib/modules/rides/ride_detail_view.dart`, `ride_detail_controller.dart`, `ride_detail_binding.dart`
- Delete: `lib/modules/home/home_view.dart`, `home_controller.dart`, `home_binding.dart`
- Test: on-device (streams/Firestore).

**Interfaces:**
- Consumes: `RideService.watchRide/watchMembers/watchRequests/acceptRequest/rejectRequest/endRide/leaveRide` (Task 3), `AuthService`, `ThemeService`, `share_plus`, `UiHelpers`.
- Produces: `RideDetailController(rideId)` binding streams: `Rxn<Ride> ride`, `RxList<RideMember> members`, `RxList<JoinRequest> requests`; actions `accept/reject/end/leave/share`. `RideDetailView` + `RideDetailBinding` (reads `Get.arguments` as rideId).

- [ ] **Step 1: Controller**

```dart
// lib/modules/rides/ride_detail_controller.dart
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/join_request.dart';
import '../../models/ride.dart';
import '../../models/ride_member.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';

class RideDetailController extends GetxController {
  final RideService _rides = Get.find<RideService>();
  final AuthService _auth = Get.find<AuthService>();
  final String rideId;
  RideDetailController(this.rideId);

  final Rxn<Ride> ride = Rxn<Ride>();
  final RxList<RideMember> members = <RideMember>[].obs;
  final RxList<JoinRequest> requests = <JoinRequest>[].obs;
  final RxBool busy = false.obs;

  String? get uid => _auth.uid;
  bool get amHost => uid != null && (ride.value?.isHost(uid!) ?? false);

  @override
  void onInit() {
    super.onInit();
    ride.bindStream(_rides.watchRide(rideId));
    members.bindStream(_rides.watchMembers(rideId));
    requests.bindStream(_rides.watchRequests(rideId));
  }

  Future<void> accept(JoinRequest r) => _guard(() => _rides.acceptRequest(rideId, r));
  Future<void> reject(JoinRequest r) => _guard(() => _rides.rejectRequest(rideId, r.uid));

  Future<void> endRide() async {
    if (!await UiHelpers.confirm(
        title: 'End ride?', message: 'No one will be able to join after this.',
        confirmText: 'End ride', destructive: true)) return;
    await _guard(() => _rides.endRide(rideId));
  }

  Future<void> leave() async {
    if (!await UiHelpers.confirm(
        title: 'Leave ride?', message: 'You can rejoin later with the code.',
        confirmText: 'Leave', destructive: true)) return;
    await _guard(() async { await _rides.leaveRide(rideId); Get.back(); });
  }

  void share() {
    final r = ride.value;
    if (r == null) return;
    SharePlus.instance.share(ShareParams(
      text: 'Join my RideTogether ride "${r.name}" with code: ${r.code}'));
  }

  Future<void> _guard(Future<void> Function() action) async {
    busy.value = true;
    try { await action(); }
    catch (e) { UiHelpers.error(e.toString().replaceFirst('Exception: ', '')); }
    finally { busy.value = false; }
  }
}
```

- [ ] **Step 2: Binding**

```dart
// lib/modules/rides/ride_detail_binding.dart
import 'package:get/get.dart';
import 'ride_detail_controller.dart';

class RideDetailBinding extends Bindings {
  @override
  void dependencies() {
    final String rideId = Get.arguments as String;
    Get.lazyPut<RideDetailController>(() => RideDetailController(rideId));
  }
}
```

- [ ] **Step 3: View**

```dart
// lib/modules/rides/ride_detail_view.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../models/join_request.dart';
import '../../models/ride_member.dart';
import '../../widgets/loading_overlay.dart';
import 'ride_detail_controller.dart';

class RideDetailView extends GetView<RideDetailController> {
  const RideDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final ride = controller.ride.value;
      return Scaffold(
        appBar: AppBar(
          title: Text(ride?.name ?? 'Ride'),
          actions: [
            IconButton(onPressed: controller.share,
                icon: const Icon(Icons.share_rounded)),
          ],
        ),
        body: LoadingOverlay(
          isLoading: controller.busy.value,
          child: ride == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(20), children: [
                  _codeCard(context, ride.code, ride.destinationLabel, ride.isActive),
                  const SizedBox(height: 24),
                  if (controller.amHost) ...[
                    _sectionTitle(context, 'Pending requests'),
                    Obx(() => controller.requests.isEmpty
                        ? _muted(context, 'No pending requests')
                        : Column(children: controller.requests
                            .map((r) => _RequestTile(req: r)).toList())),
                    const SizedBox(height: 24),
                  ],
                  _sectionTitle(context, 'Members (${controller.members.length})'),
                  Obx(() => Column(children: controller.members
                      .map((m) => _MemberTile(member: m)).toList())),
                  const SizedBox(height: 32),
                  if (controller.amHost && ride.isActive)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: controller.endRide,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('End ride')),
                  if (!controller.amHost)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: controller.leave,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Leave ride')),
                ]),
        ),
      );
    });
  }

  Widget _codeCard(BuildContext ctx, String code, String dest, bool active) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.horizon, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.place_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(dest,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis)),
          if (!active)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Ended', style: TextStyle(color: Colors.white, fontSize: 12))),
        ]),
        const SizedBox(height: 14),
        const Text('RIDE CODE', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 4),
        SelectableText(code, style: const TextStyle(color: Colors.white,
            fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 6)),
      ]),
    );
  }

  Widget _sectionTitle(BuildContext ctx, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t, style: Theme.of(ctx).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800)));

  Widget _muted(BuildContext ctx, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(t, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)));
}

class _RequestTile extends StatelessWidget {
  final JoinRequest req;
  const _RequestTile({required this.req});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<RideDetailController>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: req.photoUrl != null
            ? CachedNetworkImageProvider(req.photoUrl!) : null,
        child: req.photoUrl == null ? const Icon(Icons.person) : null),
      title: Text(req.name),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: () => c.accept(req),
            icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A))),
        IconButton(onPressed: () => c.reject(req),
            icon: const Icon(Icons.cancel, color: Color(0xFFDC2626))),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final RideMember member;
  const _MemberTile({required this.member});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: member.color,
        backgroundImage: member.photoUrl != null
            ? CachedNetworkImageProvider(member.photoUrl!) : null,
        child: member.photoUrl == null
            ? Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white)) : null),
      title: Text(member.name),
      trailing: member.isHost
          ? const Chip(label: Text('Host'), visualDensity: VisualDensity.compact)
          : null,
    );
  }
}
```

- [ ] **Step 4: Delete old home module** — remove `lib/modules/home/` (3 files). Ensure no imports remain (grep `modules/home`).
- [ ] **Step 5: `flutter analyze` — expect no issues** across the whole project.
- [ ] **Step 6: commit** `feat(phase2): ride detail (members/approval/end/leave) + remove home stub`.

---

### Task 8: On-device verification

**Files:** none (manual/observed).

- [ ] **Step 1:** `flutter run -d emulator-5554`; sign in.
- [ ] **Step 2:** Create tab → name "Test Ride", search a destination (e.g. "Rishikesh"), pick a result, Create → code sheet appears; note the code.
- [ ] **Step 3:** My Rides tab shows the ride with a Host star. Open it → code card + destination + "Members (1)" with Host chip.
- [ ] **Step 4:** (Second account/emulator or reuse) Join tab → enter code → "Waiting for approval". Host's Ride Detail shows the pending request live. Accept → requester flips to "You're in!"; member count → 2.
- [ ] **Step 5:** Verify Firestore console shows `rides/{id}`, `members`, `requests`, and `users/{uid}/rideRefs`.
- [ ] **Step 6:** Screenshot each screen; confirm no errors in logcat (`flutter :` ERROR lines).

---

## Self-Review notes
- **Spec coverage:** rides model ✓(T1), Nominatim ✓(T2), create+code+share ✓(T3,T5), join request ✓(T3,T6), approve/reject ✓(T3,T7), tabs shell ✓(T4), ride detail/members/end/leave ✓(T7), rideRefs denormalization ✓(T3), verification ✓(T8).
- **Type consistency:** `RideDestination`, `PlaceResult.lat/lng/displayName`, `RideMember.colorValue/color`, `JoinRequest.status` helpers, `RideService` method names used identically across T4–T7.
- **Note:** `toARGB32()` is the current Flutter API for a Color's int value (replaces deprecated `.value`).
- **Compile ordering:** Tasks 4–7 are interdependent (shell imports tabs + detail). Build T4→T7 before running; analyze gate is at end of T7.
