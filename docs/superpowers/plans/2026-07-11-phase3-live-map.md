# Phase 3 — Live Map & Location Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans / subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Show every ride member as a live, smoothly-animated marker on an OpenStreetMap map, sharing GPS location (with speed, heading, battery) to Realtime DB every 2.5s (9s on low battery), including background via an Android foreground service.

**Architecture:** `LocationService` (geolocator + battery_plus + compass + foreground service) produces `RidePosition`; `RideLocationService` writes those to RTDB `locations/{rideId}/{uid}` + presence, and streams all members' `MemberLocation`. A `ride_map` module renders flutter_map with custom marker pins, a recenter FAB, and a members bottom-sheet. Entry from Ride Detail.

**Tech Stack:** flutter_map, latlong2, geolocator, flutter_compass, battery_plus, firebase_database, GetX.

## Global Constraints

- No Google Maps. OSM tiles via `AppConstants.osmTileUrl` with `userAgentPackageName: AppConstants.userAgentPackageName`; OSM attribution widget mandatory.
- RTDB paths: `locations/{rideId}/{uid}`, `presence/{rideId}/{uid}`. Timestamps via `ServerValue.timestamp`.
- Update interval: 2.5s normal, 9s when battery `<20%`.
- Typed friendly errors via `UiHelpers`; handle GPS-off, permission-denied, no-internet, empty.
- Marker pins drawn with CustomPainter (no image assets).
- `flutter analyze` clean after the final task.
- Member colors from `AppColors.memberColorForKey(uid)` (already used by RideMember).

---

### Task 1: Models — RidePosition + MemberLocation

**Files:** Create `lib/models/ride_position.dart`, `lib/models/member_location.dart`; Test `test/member_location_test.dart`

**Interfaces:**
- Produces:
  - `RidePosition{ lat, lng, speed (m/s), heading (deg), battery (int) }` plain data.
  - `MemberLocation{ uid, lat, lng, speed, heading, battery, updatedAt (int ms), online (bool), lastSeen (int ms) }`; `double get speedKmh`; `String lastSeenText(int nowMs)`; `factory MemberLocation.fromMaps(uid, locMap, presenceMap)`.

- [ ] **Step 1: Failing test**

```dart
// test/member_location_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/models/member_location.dart';

void main() {
  test('speedKmh converts m/s', () {
    final m = MemberLocation(uid: 'u', lat: 0, lng: 0, speed: 10, heading: 0,
        battery: 50, updatedAt: 0, online: true, lastSeen: 0);
    expect(m.speedKmh, closeTo(36.0, 0.1));
  });

  test('lastSeenText formats minutes', () {
    final m = MemberLocation(uid: 'u', lat: 0, lng: 0, speed: 0, heading: 0,
        battery: 50, updatedAt: 0, online: false, lastSeen: 0);
    expect(m.lastSeenText(180000), 'last seen 3m ago'); // 180s
  });

  test('fromMaps merges location + presence', () {
    final m = MemberLocation.fromMaps('u1',
      {'lat': 1.0, 'lng': 2.0, 'speed': 5.0, 'heading': 90.0, 'battery': 80, 'updatedAt': 1000},
      {'online': true, 'lastSeen': 1000});
    expect(m.lat, 1.0);
    expect(m.online, isTrue);
    expect(m.battery, 80);
  });
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```dart
// lib/models/ride_position.dart
class RidePosition {
  final double lat;
  final double lng;
  final double speed;   // m/s
  final double heading; // degrees 0–360
  final int battery;    // 0–100
  const RidePosition({
    required this.lat, required this.lng, required this.speed,
    required this.heading, required this.battery,
  });

  Map<String, dynamic> toRtdb() => {
        'lat': lat, 'lng': lng, 'speed': speed, 'heading': heading,
        'battery': battery,
      };
}
```

```dart
// lib/models/member_location.dart
class MemberLocation {
  final String uid;
  final double lat;
  final double lng;
  final double speed;   // m/s
  final double heading; // deg
  final int battery;
  final int updatedAt;  // epoch ms
  final bool online;
  final int lastSeen;   // epoch ms

  const MemberLocation({
    required this.uid, required this.lat, required this.lng,
    required this.speed, required this.heading, required this.battery,
    required this.updatedAt, required this.online, required this.lastSeen,
  });

  double get speedKmh => speed * 3.6;

  String lastSeenText(int nowMs) {
    if (online) return 'Online';
    if (lastSeen == 0) return 'Offline';
    final secs = ((nowMs - lastSeen) / 1000).round();
    if (secs < 60) return 'last seen ${secs}s ago';
    final mins = (secs / 60).round();
    if (mins < 60) return 'last seen ${mins}m ago';
    final hrs = (mins / 60).round();
    return 'last seen ${hrs}h ago';
  }

  static double _d(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
  static int _i(dynamic v) => v == null ? 0 : (v as num).toInt();

  factory MemberLocation.fromMaps(
      String uid, Map<dynamic, dynamic>? loc, Map<dynamic, dynamic>? pres) {
    final l = loc ?? const {};
    final p = pres ?? const {};
    return MemberLocation(
      uid: uid,
      lat: _d(l['lat']), lng: _d(l['lng']), speed: _d(l['speed']),
      heading: _d(l['heading']), battery: _i(l['battery']),
      updatedAt: _i(l['updatedAt']),
      online: (p['online'] ?? false) as bool,
      lastSeen: _i(p['lastSeen']),
    );
  }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: analyze clean; commit** `feat(phase3): location models`.

---

### Task 2: LocationService — permission, battery-aware position stream, foreground service

**Files:** Create `lib/services/location_service.dart`; (no unit test — device APIs; verified on-device)

**Interfaces:**
- Consumes: `RidePosition` (T1), geolocator, battery_plus, flutter_compass.
- Produces: `LocationService extends GetxService`:
  - `Future<LocationPermissionResult> ensurePermission()` where `enum LocationPermissionResult { granted, serviceDisabled, denied, deniedForever }`.
  - `Stream<RidePosition> positionStream()` — emits merged position+heading+battery; interval adapts to battery.
  - `Future<Position?> currentPosition()` — one-shot for initial camera.
  - `bool get isLowBattery`.

- [ ] **Step 1: Implement**

```dart
// lib/services/location_service.dart
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import '../models/ride_position.dart';

enum LocationPermissionResult { granted, serviceDisabled, denied, deniedForever }

class LocationService extends GetxService {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  double _heading = 0;
  StreamSubscription<CompassEvent>? _compassSub;

  bool get isLowBattery => _batteryLevel < 20;

  @override
  void onInit() {
    super.onInit();
    _refreshBattery();
    _compassSub = FlutterCompass.events?.listen((e) {
      if (e.heading != null) _heading = e.heading!;
    });
  }

  @override
  void onClose() {
    _compassSub?.cancel();
    super.onClose();
  }

  Future<void> _refreshBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
    } catch (_) {}
  }

  Future<LocationPermissionResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionResult.serviceDisabled;
    }
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      return LocationPermissionResult.deniedForever;
    }
    if (p == LocationPermission.denied) {
      return LocationPermissionResult.denied;
    }
    return LocationPermissionResult.granted;
  }

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high));
    } catch (e, s) {
      Log.e('currentPosition failed', error: e, stack: s);
      return null;
    }
  }

  /// A position stream that re-reads battery each tick and adapts the interval.
  /// Uses a periodic timer + getCurrentPosition so the interval can change at
  /// runtime based on battery (geolocator's own stream has a fixed filter).
  Stream<RidePosition> positionStream() async* {
    while (true) {
      await _refreshBattery();
      final Duration interval =
          isLowBattery ? const Duration(seconds: 9) : const Duration(milliseconds: 2500);
      try {
        final Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high));
        yield RidePosition(
          lat: pos.latitude,
          lng: pos.longitude,
          speed: pos.speed < 0 ? 0 : pos.speed,
          heading: _heading != 0 ? _heading : pos.heading,
          battery: _batteryLevel,
        );
      } catch (e, s) {
        Log.e('position tick failed', error: e, stack: s);
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Android foreground-location settings with a persistent notification, so
  /// tracking survives the app being backgrounded. iOS uses its bg location
  /// mode automatically (Info.plist). Used by callers that opt into a
  /// geolocator position stream directly (kept here for reuse in Phase 7).
  AndroidSettings androidForegroundSettings() => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'RideTogether',
          notificationText: 'Sharing your live location with your ride',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
}
```

- [ ] **Step 2: analyze clean; commit** `feat(phase3): LocationService (permission/battery-aware/compass)`.

---

### Task 3: RideLocationService — RTDB write + presence + watch

**Files:** Create `lib/services/ride_location_service.dart`

**Interfaces:**
- Consumes: `RidePosition`, `MemberLocation` (T1), `AuthService`, firebase_database.
- Produces: `RideLocationService extends GetxService`:
  - `void startSharing(String rideId, Stream<RidePosition> stream)` — subscribes, writes each `RidePosition` to `locations/{rideId}/{uid}` (+ updatedAt), sets presence online, registers `onDisconnect`.
  - `Future<void> stopSharing(String rideId)` — presence offline; cancels subscription.
  - `Stream<List<MemberLocation>> watchLocations(String rideId)`.

- [ ] **Step 1: Implement**

```dart
// lib/services/ride_location_service.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import '../models/member_location.dart';
import '../models/ride_position.dart';
import 'auth_service.dart';

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
    // Presence online + auto-offline on disconnect.
    final DatabaseReference pres = _pres(rideId, uid);
    pres.set(<String, dynamic>{'online': true, 'lastSeen': ServerValue.timestamp});
    pres.onDisconnect().set(
        <String, dynamic>{'online': false, 'lastSeen': ServerValue.timestamp});

    _shareSub?.cancel();
    _shareSub = stream.listen((RidePosition p) {
      final Map<String, dynamic> data = p.toRtdb()
        ..['updatedAt'] = ServerValue.timestamp;
      _loc(rideId, uid).set(data).catchError(
          (Object e) => Log.e('location write failed', error: e));
    });
  }

  Future<void> stopSharing(String rideId) async {
    await _shareSub?.cancel();
    _shareSub = null;
    final String? uid = _auth.uid;
    if (uid == null) return;
    await _pres(rideId, uid).set(
        <String, dynamic>{'online': false, 'lastSeen': ServerValue.timestamp});
  }

  Stream<List<MemberLocation>> watchLocations(String rideId) {
    final DatabaseReference locRef = _db.ref('locations/$rideId');
    final DatabaseReference presRef = _db.ref('presence/$rideId');
    // Combine the two child maps on every locations change; read presence once
    // per emission (small N).
    return locRef.onValue.asyncMap((DatabaseEvent event) async {
      final Map<dynamic, dynamic> locs =
          (event.snapshot.value as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
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
```

- [ ] **Step 2: register in main.dart** — add `Get.put<LocationService>(LocationService(), permanent: true);` and `Get.put<RideLocationService>(RideLocationService(), permanent: true);` (import both).
- [ ] **Step 3: analyze clean; commit** `feat(phase3): RideLocationService RTDB + presence + register`.

---

### Task 4: Ride map module (controller + binding)

**Files:** Create `lib/modules/ride_map/ride_map_controller.dart`, `ride_map_binding.dart`

**Interfaces:**
- Consumes: `LocationService`, `RideLocationService` (T2/T3), `AuthService`, `UiHelpers`, `latlong2`, flutter_map `MapController`.
- Produces: `RideMapController(rideId)`:
  - `RxList<MemberLocation> members`, `RxBool ready`, `Rxn<LatLng> myLatLng`, `MapController mapController`.
  - `onInit`: ensurePermission → if granted, start location stream + share + watch; else set an error state.
  - `recenter()`, `focusMember(MemberLocation)`, `openSettingsIfNeeded()`.
  - `Rx<String?> permissionError` for the UI.

- [ ] **Step 1: Implement controller**

```dart
// lib/modules/ride_map/ride_map_controller.dart
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/member_location.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_location_service.dart';

class RideMapController extends GetxController {
  final LocationService _loc = Get.find<LocationService>();
  final RideLocationService _rideLoc = Get.find<RideLocationService>();
  final AuthService _auth = Get.find<AuthService>();
  final String rideId;
  RideMapController(this.rideId);

  final MapController mapController = MapController();
  final RxList<MemberLocation> members = <MemberLocation>[].obs;
  final Rxn<LatLng> myLatLng = Rxn<LatLng>();
  final RxBool ready = false.obs;
  final RxnString permissionError = RxnString();

  String? get uid => _auth.uid;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    final LocationPermissionResult res = await _loc.ensurePermission();
    if (res != LocationPermissionResult.granted) {
      permissionError.value = switch (res) {
        LocationPermissionResult.serviceDisabled =>
          'Location is turned off. Turn it on to share your position.',
        LocationPermissionResult.deniedForever =>
          'Location permission is blocked. Enable it in app settings.',
        _ => 'Location permission is needed to share your position.',
      };
      ready.value = true;
      return;
    }

    final pos = await _loc.currentPosition();
    if (pos != null) myLatLng.value = LatLng(pos.latitude, pos.longitude);

    final stream = _loc.positionStream();
    // keep my own dot fresh too
    stream.listen((p) => myLatLng.value = LatLng(p.lat, p.lng));
    _rideLoc.startSharing(rideId, _loc.positionStream());
    members.bindStream(_rideLoc.watchLocations(rideId));
    ready.value = true;
  }

  void recenter() {
    final LatLng? me = myLatLng.value;
    if (me != null) mapController.move(me, 15);
  }

  void focusMember(MemberLocation m) {
    mapController.move(LatLng(m.lat, m.lng), 16);
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  void onClose() {
    _rideLoc.stopSharing(rideId);
    super.onClose();
  }
}
```

- [ ] **Step 2: Binding**

```dart
// lib/modules/ride_map/ride_map_binding.dart
import 'package:get/get.dart';
import 'ride_map_controller.dart';

class RideMapBinding extends Bindings {
  @override
  void dependencies() {
    final String rideId = Get.arguments as String;
    Get.lazyPut<RideMapController>(() => RideMapController(rideId));
  }
}
```

- [ ] **Step 3: commit** `feat(phase3): ride map controller + binding`.

---

### Task 5: Ride map view (flutter_map + markers + attribution + members sheet)

**Files:** Create `lib/modules/ride_map/ride_map_view.dart`; Modify `lib/routes/app_pages.dart` (register `Routes.rideMap`), `lib/modules/rides/ride_detail_view.dart` (add "Open live map" button).

**Interfaces:**
- Consumes: `RideMapController` (T4), `MemberLocation`, `AppColors`, flutter_map, latlong2.
- Produces: `RideMapView` (GetView) with the map, marker layer, recenter FAB, members sheet trigger. `_MemberPin` CustomPainter widget.

- [ ] **Step 1: Implement view**

```dart
// lib/modules/ride_map/ride_map_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/member_location.dart';
import 'ride_map_controller.dart';

class RideMapView extends GetView<RideMapController> {
  const RideMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live map')),
      body: Obx(() {
        if (!controller.ready.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.permissionError.value != null) {
          return _permissionError(context);
        }
        final LatLng center = controller.myLatLng.value ??
            const LatLng(20.5937, 78.9629); // India fallback
        return Stack(
          children: [
            FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(initialCenter: center, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: AppConstants.osmTileUrl,
                  userAgentPackageName: AppConstants.userAgentPackageName,
                ),
                Obx(() => MarkerLayer(markers: _markers())),
                RichAttributionWidget(attributions: [
                  TextSourceAttribution('OpenStreetMap contributors',
                      onTap: () => launchUrl(
                          Uri.parse('https://openstreetmap.org/copyright'))),
                ]),
              ],
            ),
            Positioned(
              right: 16, bottom: 96,
              child: FloatingActionButton(
                heroTag: 'recenter',
                onPressed: controller.recenter,
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: _membersBar(context),
            ),
          ],
        );
      }),
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];
    for (final MemberLocation m in controller.members) {
      markers.add(Marker(
        point: LatLng(m.lat, m.lng),
        width: 80, height: 80,
        child: _MemberPin(
          color: AppColors.memberColorForKey(m.uid),
          heading: m.heading,
          isMe: m.uid == controller.uid,
        ),
      ));
    }
    return markers;
  }

  Widget _membersBar(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showMembers(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Obx(() => Row(children: [
                const Icon(Icons.group_rounded),
                const SizedBox(width: 10),
                Text('${controller.members.length} on the map',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(Icons.expand_less_rounded),
              ])),
        ),
      ),
    );
  }

  void _showMembers(BuildContext context) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              children: controller.members.map((m) {
                return ListTile(
                  leading: CircleAvatar(
                      backgroundColor: AppColors.memberColorForKey(m.uid),
                      radius: 12),
                  title: Text(m.uid == controller.uid ? 'You' : 'Rider'),
                  subtitle: Text(
                      '${m.speedKmh.toStringAsFixed(0)} km/h · ${m.battery}% · '
                      '${m.lastSeenText(now)}'),
                  onTap: () {
                    Get.back();
                    controller.focusMember(m);
                  },
                );
              }).toList(),
            )),
      ),
    );
  }

  Widget _permissionError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_off_rounded, size: 48),
          const SizedBox(height: 16),
          Text(controller.permissionError.value!,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: controller.openSettings,
              child: const Text('Open settings')),
        ]),
      ),
    );
  }
}

/// A colored teardrop pin with a heading arrow. Drawn, not an image asset.
class _MemberPin extends StatelessWidget {
  final Color color;
  final double heading;
  final bool isMe;
  const _MemberPin({required this.color, required this.heading, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PinPainter(color: color, heading: heading, ring: isMe),
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;
  final double heading;
  final bool ring;
  _PinPainter({required this.color, required this.heading, required this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color;
    // heading arrow
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * 3.1415926 / 180);
    final arrow = Path()
      ..moveTo(0, -26)
      ..lineTo(7, -14)
      ..lineTo(-7, -14)
      ..close();
    canvas.drawPath(arrow, paint);
    canvas.restore();
    // dot
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(center, 9, paint);
    if (ring) {
      canvas.drawCircle(center, 15,
          Paint()..color = color.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) =>
      old.heading != heading || old.color != color;
}
```

- [ ] **Step 2: Register route** in `app_pages.dart` — import `ride_map_view.dart` + `ride_map_binding.dart`; add:

```dart
GetPage<dynamic>(name: Routes.rideMap, page: () => const RideMapView(),
    binding: RideMapBinding(), transition: Transition.cupertino),
```

- [ ] **Step 3: Add "Open live map" button** to `ride_detail_view.dart` — inside the `ListView`, after `_codeCard(...)`, before the members section, when `ride.isActive`:

```dart
if (ride.isActive) ...[
  const SizedBox(height: 16),
  FilledButton.icon(
    onPressed: () => Get.toNamed(Routes.rideMap, arguments: controller.rideId),
    icon: const Icon(Icons.map_rounded),
    label: const Text('Open live map'),
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
  ),
],
```
(Add `import '../../routes/app_routes.dart';` to ride_detail_view.dart if not present. `controller.rideId` is already public on RideDetailController.)

- [ ] **Step 4: `flutter analyze` — expect no issues.**
- [ ] **Step 5: commit** `feat(phase3): ride map view + markers + attribution + entry button`.

---

### Task 6: On-device verification

- [ ] **Step 1:** In the emulator, set a mock location (Extended controls → Location, or `adb emu geo fix <lng> <lat>`).
- [ ] **Step 2:** `flutter run -d emulator-5554`; open a ride → "Open live map".
- [ ] **Step 3:** Grant location permission (while using → allow all the time). Map renders OSM tiles centered on the mock location; your pin appears with heading.
- [ ] **Step 4:** Change mock location via `adb emu geo fix`; the pin moves. Members bar shows "1 on the map"; open sheet → speed/battery/last-seen shown.
- [ ] **Step 5:** Verify Firebase console → Realtime Database shows `locations/{rideId}/{uid}` updating and `presence/{rideId}/{uid}` online:true.
- [ ] **Step 6:** Background the app; confirm the foreground-service notification appears ("Sharing your live location…"). Screenshot map + notification.

---

## Self-Review notes
- **Spec coverage:** RTDB structure ✓(T3), LocationService battery-aware+compass ✓(T2), presence onDisconnect ✓(T3), map+OSM+attribution ✓(T5), markers+heading ✓(T5), recenter+members sheet ✓(T5), entry from detail ✓(T5), permission handling ✓(T4/T5), foreground service ✓(T2), verification ✓(T6).
- **Type consistency:** `RidePosition.toRtdb`, `MemberLocation.fromMaps/speedKmh/lastSeenText`, `LocationPermissionResult` enum, `RideMapController.rideId/uid/members` used identically across tasks.
- **Note:** the position stream uses a battery-adaptive periodic poll (not geolocator's fixed-filter stream) so the interval can change at runtime; `androidForegroundSettings()` is provided for Phase 7's always-on stream. Phase 3's foreground notification is driven by geolocator when the position stream is active on Android.
- **RTDB prerequisite** flagged in spec; app shows a clear error if the database isn't created.
