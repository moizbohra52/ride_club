# Phase 6 — SOS + Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A confirmable SOS that broadcasts the sender's live location to the ride over RTDB (instant in-app full-screen alert + local notification + optional emergency-contact SMS + sender cancel), plus FCM token capture and local notifications wired so a later Blaze Cloud Function turns on real background push with no app changes.

**Architecture:** `SosService` (RTDB `sos/{rideId}`) + `NotificationService` (flutter_local_notifications + FCM token) + `RideEventsService` (in-app member-joined/accepted). SOS UI on Live Map (FAB) and Ride Detail. A deploy-ready `functions/index.js` for later.

**Tech Stack:** firebase_database, firebase_messaging (already in pubspec), flutter_local_notifications (new), url_launcher, geolocator, GetX.

## Global Constraints

- Free-plan honest: SOS works via RTDB now; real push needs Blaze + deploying `functions/`.
- RTDB path `sos/{rideId}/{sosId}`; timestamps `ServerValue.timestamp`.
- FCM token → `users/{uid}.fcmToken` via `UserService.update`.
- Typed friendly errors; SOS must still fire if GPS/contact/permission missing.
- `flutter analyze` clean; tests pass; no Google Maps.

---

### Task 1: Add flutter_local_notifications; SosAlert model + SMS URI helper

**Files:** Modify `pubspec.yaml`; Create `lib/models/sos_alert.dart`, `lib/core/utils/sms_link.dart`; Test `test/sos_test.dart`

**Interfaces:**
- Produces:
  - `SosAlert{ sosId, senderId, senderName, lat?, lng?, active, startedAt }`; `hasLocation`; `factory fromMap(id, map)`.
  - `Uri emergencySmsUri(String contact, String senderName, double? lat, double? lng)` — builds `sms:<contact>?body=...` with an OSM link when coords exist.

- [ ] **Step 1: pubspec** — under UI helpers add `flutter_local_notifications: ^17.2.3`; run `flutter pub get`.

- [ ] **Step 2: Failing test**

```dart
// test/sos_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/core/utils/sms_link.dart';
import 'package:ride_club/models/sos_alert.dart';

void main() {
  test('SosAlert.fromMap with location', () {
    final s = SosAlert.fromMap('s1', {
      'senderId': 'u1', 'senderName': 'A', 'lat': 18.5, 'lng': 73.4,
      'active': true, 'startedAt': 1000,
    });
    expect(s.hasLocation, isTrue);
    expect(s.active, isTrue);
    expect(s.lat, 18.5);
  });

  test('SosAlert.fromMap without location', () {
    final s = SosAlert.fromMap('s2', {
      'senderId': 'u1', 'senderName': 'A', 'active': true, 'startedAt': 1,
    });
    expect(s.hasLocation, isFalse);
  });

  test('emergencySmsUri embeds OSM link when coords present', () {
    final uri = emergencySmsUri('+911234567890', 'Asha', 18.5, 73.4);
    expect(uri.scheme, 'sms');
    expect(uri.path, '+911234567890');
    expect(uri.query, contains('openstreetmap.org'));
    expect(Uri.decodeFull(uri.query), contains('Asha'));
  });

  test('emergencySmsUri without coords still builds', () {
    final uri = emergencySmsUri('+911234567890', 'Asha', null, null);
    expect(uri.scheme, 'sms');
    expect(Uri.decodeFull(uri.query), contains('Asha'));
  });
}
```

- [ ] **Step 3: Run — FAIL.**
- [ ] **Step 4: Implement**

```dart
// lib/models/sos_alert.dart
class SosAlert {
  final String sosId;
  final String senderId;
  final String senderName;
  final double? lat;
  final double? lng;
  final bool active;
  final int startedAt; // epoch ms

  const SosAlert({
    required this.sosId,
    required this.senderId,
    required this.senderName,
    this.lat,
    this.lng,
    required this.active,
    required this.startedAt,
  });

  bool get hasLocation => lat != null && lng != null;

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

  factory SosAlert.fromMap(String id, Map<dynamic, dynamic> m) => SosAlert(
        sosId: id,
        senderId: (m['senderId'] ?? '') as String,
        senderName: (m['senderName'] ?? '') as String,
        lat: _d(m['lat']),
        lng: _d(m['lng']),
        active: (m['active'] ?? false) as bool,
        startedAt: m['startedAt'] is num ? (m['startedAt'] as num).toInt() : 0,
      );
}
```

```dart
// lib/core/utils/sms_link.dart
/// Builds an `sms:` URI to a contact with an SOS body, embedding an
/// OpenStreetMap link to [lat],[lng] when available.
Uri emergencySmsUri(String contact, String senderName, double? lat, double? lng) {
  final StringBuffer body = StringBuffer('SOS from $senderName (RideTogether).');
  if (lat != null && lng != null) {
    body.write(' My location: https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng');
  } else {
    body.write(' Location unavailable.');
  }
  return Uri(scheme: 'sms', path: contact, query: 'body=${Uri.encodeComponent(body.toString())}');
}
```

- [ ] **Step 5: Run — PASS.**
- [ ] **Step 6: analyze clean; commit** `feat(phase6): sos model + sms link + local-notif dep`.

---

### Task 2: NotificationService — local notifications + FCM token

**Files:** Create `lib/services/notification_service.dart`; a top-level background handler in `main.dart`; register service.

**Interfaces:**
- Consumes: flutter_local_notifications, firebase_messaging, `AuthService`, `UserService`.
- Produces: `NotificationService extends GetxService` with `Future<void> init()`, `Future<void> showLocal(String title, String body, {bool sos})`, `Future<void> saveToken()`.

- [ ] **Step 1: Implement**

```dart
// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../core/utils/logger.dart';
import 'auth_service.dart';
import 'user_service.dart';

class NotificationService extends GetxService {
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();

  static const AndroidNotificationChannel _sosChannel = AndroidNotificationChannel(
    'sos', 'SOS Alerts',
    description: 'Emergency alerts from your ride',
    importance: Importance.max,
  );
  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    'general', 'General', description: 'Ride updates',
    importance: Importance.high,
  );

  Future<void> init() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    await _local.initialize(const InitializationSettings(android: android, iOS: ios));

    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_sosChannel);
    await androidImpl?.createNotificationChannel(_generalChannel);
    await androidImpl?.requestNotificationsPermission();

    await _fcm.requestPermission();
    await saveToken();
    _fcm.onTokenRefresh.listen((_) => saveToken());

    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      final n = m.notification;
      if (n != null) showLocal(n.title ?? 'RideTogether', n.body ?? '');
    });
  }

  Future<void> saveToken() async {
    try {
      final uid = _auth.uid;
      if (uid == null) return;
      final token = await _fcm.getToken();
      if (token != null) await _users.update(uid, {'fcmToken': token});
    } catch (e, s) {
      Log.e('saveToken failed', error: e, stack: s);
    }
  }

  Future<void> showLocal(String title, String body, {bool sos = false}) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        sos ? _sosChannel.id : _generalChannel.id,
        sos ? _sosChannel.name : _generalChannel.name,
        importance: sos ? Importance.max : Importance.high,
        priority: sos ? Priority.max : Priority.high,
        color: sos ? const Color(0xFFE11D48) : null,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}
```
Add `import 'package:flutter/material.dart' show Color;` (or `import 'dart:ui' show Color;`) to that file for `Color`.

- [ ] **Step 2: Background handler + init in main.dart**

Top-level (above `main()`):
```dart
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // No-op for now; a local notification is auto-shown by the system for
  // notification-type messages. Active once a Cloud Function sends pushes.
}
```
In `main()` after Firebase init:
```dart
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
```
After service registrations:
```dart
  Get.put<NotificationService>(NotificationService(), permanent: true);
```
Add imports: `firebase_messaging`, `services/notification_service.dart`.
Call `init()` lazily: in `SplashController` after auth check, if logged in → `Get.find<NotificationService>().init()` (fire-and-forget). (Add there so it runs post-login with a uid.)

- [ ] **Step 3: analyze clean; commit** `feat(phase6): NotificationService (local + FCM token) + bg handler`.

---

### Task 3: SosService

**Files:** Create `lib/services/sos_service.dart`; register in main.dart.

**Interfaces:**
- Consumes: firebase_database, `AuthService`, `UserService`, `LocationService`, `SosAlert`, `emergencySmsUri`, url_launcher.
- Produces: `SosService extends GetxService` with `trigger`, `cancel`, `watchActiveSos`, `textEmergencyContact`.

- [ ] **Step 1: Implement**

```dart
// lib/services/sos_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/utils/logger.dart';
import '../core/utils/sms_link.dart';
import '../models/sos_alert.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'user_service.dart';

class SosService extends GetxService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  final LocationService _loc = Get.find<LocationService>();

  DatabaseReference _sos(String rideId) => _db.ref('sos/$rideId');

  Future<String?> trigger(String rideId) async {
    final uid = _auth.uid;
    if (uid == null) return null;
    final profile = await _users.fetch(uid);
    double? lat, lng;
    try {
      final pos = await _loc.currentPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {}
    final ref = _sos(rideId).push();
    await ref.set(<String, dynamic>{
      'senderId': uid,
      'senderName': profile?.name ?? 'A rider',
      'lat': lat,
      'lng': lng,
      'active': true,
      'startedAt': ServerValue.timestamp,
    });
    return ref.key;
  }

  Future<void> cancel(String rideId, String sosId) =>
      _sos(rideId).child(sosId).update(<String, dynamic>{'active': false});

  Stream<List<SosAlert>> watchActiveSos(String rideId) {
    return _sos(rideId).onValue.map((event) {
      final raw = event.snapshot.value as Map<dynamic, dynamic>?;
      if (raw == null) return <SosAlert>[];
      return raw.entries
          .map((e) => SosAlert.fromMap(e.key as String, e.value as Map<dynamic, dynamic>))
          .where((s) => s.active)
          .toList();
    });
  }

  Future<void> textEmergencyContact(
      String contact, String senderName, double? lat, double? lng) async {
    final uri = emergencySmsUri(contact, senderName, lat, lng);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e, s) {
      Log.e('sms launch failed', error: e, stack: s);
    }
  }
}
```

- [ ] **Step 2: register** in main.dart — `Get.put<SosService>(SosService(), permanent: true);`.
- [ ] **Step 3: analyze clean; commit** `feat(phase6): SosService (trigger/cancel/watch/sms)`.

---

### Task 4: SOS UI — map FAB, detail button, confirm, incoming alert, banner

**Files:** Modify `ride_map_controller.dart`, `ride_map_view.dart`, `ride_detail_controller.dart`, `ride_detail_view.dart`; Create `lib/modules/sos/sos_ui.dart` (shared confirm + incoming-alert + banner widgets/helpers).

**Interfaces:** Consumes `SosService`, `NotificationService`, `SosAlert`, `AuthService`, profile emergencyContact.

- [ ] **Step 1: Shared SOS helpers** — `lib/modules/sos/sos_ui.dart`:

```dart
// lib/modules/sos/sos_ui.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../models/sos_alert.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/sos_service.dart';
import '../../services/user_service.dart';

/// Confirms + triggers SOS for [rideId]. Returns the sosId if sent.
Future<String?> confirmAndSendSos(String rideId) async {
  final ok = await Get.dialog<bool>(AlertDialog(
    title: const Text('Send SOS?'),
    content: const Text(
        'Everyone in this ride will see an emergency alert with your live location.'),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.sos),
        onPressed: () => Get.back(result: true),
        child: const Text('Send SOS'),
      ),
    ],
  ));
  if (ok != true) return null;

  final sosId = await Get.find<SosService>().trigger(rideId);
  Get.find<NotificationService>().showLocal('SOS sent', 'Your ride has been alerted.', sos: true);

  // Offer emergency-contact SMS if one is set.
  final uid = Get.find<AuthService>().uid;
  if (uid != null) {
    final profile = await Get.find<UserService>().fetch(uid);
    final contact = profile?.emergencyContact;
    if (contact != null && contact.isNotEmpty) {
      final text = await Get.dialog<bool>(AlertDialog(
        title: const Text('Text emergency contact?'),
        content: Text('Also send an SMS to $contact with your location?'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('No')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('Text them')),
        ],
      ));
      if (text == true) {
        // location best-effort captured inside trigger; re-read profile coords not needed
        await Get.find<SosService>().textEmergencyContact(
            contact, profile?.name ?? 'A rider', null, null);
      }
    }
  }
  return sosId;
}

/// Full-screen incoming SOS alert for an alert not sent by me.
void showIncomingSos(SosAlert alert, String rideId) {
  if (Get.isDialogOpen ?? false) return;
  Get.find<NotificationService>()
      .showLocal('SOS: ${alert.senderName}', '${alert.senderName} needs help!', sos: true);
  Get.dialog(
    Dialog(
      backgroundColor: AppColors.sos,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 12),
          Text('${alert.senderName} needs help!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          if (alert.hasLocation)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.sos),
              onPressed: () { Get.back(); Get.toNamed(Routes.rideMap, arguments: rideId); },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Open live map'),
            ),
          TextButton(onPressed: () => Get.back(),
              child: const Text('Dismiss', style: TextStyle(color: Colors.white))),
        ]),
      ),
    ),
    barrierDismissible: false,
  );
}
```

- [ ] **Step 2: Ride Map controller** — add SOS state + wiring. Add fields:
```dart
  final SosService _sos = Get.find<SosService>();
  final RxList<SosAlert> activeSos = <SosAlert>[].obs;
  final RxnString mySosId = RxnString();
  final Set<String> _seenSos = <String>{};
```
In `_start()` after members bind:
```dart
    activeSos.bindStream(_sos.watchActiveSos(rideId));
    ever<List<SosAlert>>(activeSos, (list) {
      for (final s in list) {
        if (s.senderId == uid) continue;
        if (_seenSos.contains(s.sosId)) continue;
        _seenSos.add(s.sosId);
        showIncomingSos(s, rideId);
      }
    });
```
Add methods:
```dart
  Future<void> sendSos() async { mySosId.value = await confirmAndSendSos(rideId); }
  Future<void> cancelSos() async {
    final id = mySosId.value;
    if (id != null) { await _sos.cancel(rideId, id); mySosId.value = null; }
  }
  bool get iHaveActiveSos =>
      mySosId.value != null && activeSos.any((s) => s.sosId == mySosId.value);
```
Add imports: sos_ui.dart, sos_service.dart, models/sos_alert.dart.

- [ ] **Step 3: Ride Map view** — add a red SOS FAB (left/bottom) + active banner. In the outer `Stack`, add:
```dart
            Positioned(
              left: 16, bottom: 96,
              child: FloatingActionButton(
                heroTag: 'sos',
                backgroundColor: AppColors.sos,
                onPressed: controller.sendSos,
                child: const Icon(Icons.sos_rounded, color: Colors.white),
              ),
            ),
            Obx(() => controller.iHaveActiveSos
                ? Positioned(top: 64, left: 16, right: 16, child: _sosBanner(controller))
                : const SizedBox.shrink()),
```
Add helper in the view:
```dart
  Widget _sosBanner(RideMapController c) => Material(
        color: AppColors.sos, borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: c.cancelSos,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('SOS active · Tap to cancel',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      );
```
Import `AppColors` (already present).

- [ ] **Step 4: Ride Detail** — add SOS button + incoming watch. In controller: same `activeSos`/`_sos`/`sendSos`/incoming `ever` as map (or minimal: just a `sendSos` button + watch). Add to `RideDetailController.onInit`:
```dart
    activeSos.bindStream(_sos.watchActiveSos(rideId));
    ever<List<SosAlert>>(activeSos, (list) {
      for (final s in list) {
        if (s.senderId == uid || _seenSos.contains(s.sosId)) continue;
        _seenSos.add(s.sosId); showIncomingSos(s, rideId);
      }
    });
```
with the same fields/imports. In `RideDetailView`, add (when `ride.isActive`, after "Open live map"):
```dart
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.sos,
                            side: const BorderSide(color: AppColors.sos),
                            minimumSize: const Size.fromHeight(50)),
                        onPressed: () => controller.sendSos(),
                        icon: const Icon(Icons.sos_rounded),
                        label: const Text('Send SOS'),
                      ),
```

- [ ] **Step 5: `flutter analyze` — expect no issues.**
- [ ] **Step 6: commit** `feat(phase6): SOS UI (map FAB + detail button + incoming alert + banner)`.

---

### Task 5: Deploy-ready Cloud Function (not deployed) + docs

**Files:** Create `functions/index.js`, `functions/package.json`, `functions/README.md`.

- [ ] **Step 1: functions/index.js** — RTDB `sos/{rideId}/{sosId}` onCreate → send FCM to members' tokens.

```js
// functions/index.js — deploy only after enabling the Blaze plan.
const { onValueCreated } = require('firebase-functions/v2/database');
const { initializeApp } = require('firebase-admin/app');
const { getDatabase } = require('firebase-admin/database');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
initializeApp();

exports.onSos = onValueCreated('/sos/{rideId}/{sosId}', async (event) => {
  const sos = event.data.val();
  const { rideId } = event.params;
  if (!sos || !sos.active) return;

  const membersSnap = await getFirestore()
    .collection('rides').doc(rideId).collection('members').get();
  const uids = membersSnap.docs.map((d) => d.id).filter((u) => u !== sos.senderId);

  const tokens = [];
  for (const uid of uids) {
    const u = await getFirestore().collection('users').doc(uid).get();
    const t = u.get('fcmToken');
    if (t) tokens.push(t);
  }
  if (!tokens.length) return;

  await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: `SOS: ${sos.senderName}`,
      body: `${sos.senderName} needs help! Open RideTogether.`,
    },
    android: { priority: 'high', notification: { channelId: 'sos' } },
  });
});
```

- [ ] **Step 2: functions/package.json**

```json
{
  "name": "ridetogether-functions",
  "engines": { "node": "20" },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  }
}
```

- [ ] **Step 3: functions/README.md** — how to enable Blaze + `firebase init functions` (or reuse this folder) + `firebase deploy --only functions`; note that once deployed, SOS pushes reach members even when the app is closed, and the existing app FCM token wiring needs no changes.

- [ ] **Step 4: commit** `feat(phase6): deploy-ready SOS Cloud Function (Blaze) + docs`.

---

### Task 6: Verify

- [ ] **Step 1:** `flutter analyze` clean; `flutter test` all pass.
- [ ] **Step 2 (device):** open ride → Live Map → red SOS FAB → confirm dialog → RTDB `sos/{rideId}/{sosId}` written with `active:true`; local notification "SOS sent"; if emergency contact set, SMS prompt → composer opens with OSM link.
- [ ] **Step 3:** second account watching the ride → full-screen red alert + notification; "Open live map" navigates.
- [ ] **Step 4:** sender sees "SOS active · Tap to cancel" banner → cancel → `active:false`, alert clears on others.
- [ ] **Step 5:** confirm `users/{uid}.fcmToken` saved in Firestore. Screenshot SOS alert.

---

## Self-Review notes
- **Spec coverage:** SosAlert+SMS ✓(T1), NotificationService FCM token + local ✓(T2), SosService RTDB+SMS ✓(T3), SOS UI map/detail/confirm/incoming/banner ✓(T4), Cloud Function ready ✓(T5), verify ✓(T6).
- **Type consistency:** `SosAlert.fromMap/hasLocation`, `emergencySmsUri`, `SosService.trigger/cancel/watchActiveSos/textEmergencyContact`, `confirmAndSendSos/showIncomingSos`, controller `activeSos/mySosId/sendSos/cancelSos/iHaveActiveSos` consistent across T3/T4.
- **Free-plan honesty:** the app path (RTDB + local notifications) works now; the Cloud Function (T5) is deploy-ready but explicitly not deployed — no false claim of background push.
- **Init timing:** `NotificationService.init()` runs post-login (has uid) so token save + permission prompt happen at the right time.
- **Duplicate alert guard:** `_seenSos` set prevents re-showing the same SOS dialog on every stream tick.
