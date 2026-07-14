# Phase 3 — Live Map & Location Sharing — Design Spec

**Date:** 2026-07-11
**Project:** `ride_club` (RideTogether)
**Builds on:** Phase 1 (auth/theme/routing), Phase 2 (rides/members/detail).

---

## Locked decisions (from brainstorming)

| Fork | Decision |
|------|----------|
| Update frequency | **2.5s normal, battery-aware** → 9s when battery < 20%. |
| Map features | Colored **name markers** with **smooth animation**, **speed (km/h) + heading arrow**, **battery% + last-seen**, **recenter FAB + members bottom-sheet**. |
| Map entry | From **Ride Detail → "Open live map"** (active rides only). |
| Background location | **Yes now** — Android foreground service + persistent notification; "Allow all the time" permission. iOS background location mode. |
| Foreground service impl | Via **geolocator's Android foreground config** (no extra paid plugin). |
| Battery % | Read own via **battery_plus**, push to RTDB; others' battery read from RTDB. |
| Marker art | **CustomPainter** pins (no image assets, offline-safe). |

## Realtime Database structure

```
locations/{rideId}/{uid}
  lat: double, lng: double, speed: double (m/s), heading: double (deg),
  battery: int (0–100), updatedAt: ServerValue.timestamp

presence/{rideId}/{uid}
  online: bool, lastSeen: ServerValue.timestamp
  // onDisconnect() sets online:false + lastSeen so offline is automatic
```

**Why RTDB (not Firestore):** rapid 2.5s writes + `onDisconnect` presence are exactly what Realtime Database is built for, and it's far cheaper than Firestore for this write volume on the Spark plan.

## Architecture

### Services (new, GetxService singletons)
- **`LocationService`** — geolocator + battery_plus + flutter_compass wrapper:
  - `Future<bool> ensurePermission()` — checks service enabled + requests while-in-use, then background ("allow all the time"); returns false with a typed reason on denial.
  - `Stream<RidePosition> positionStream()` — distance/interval-filtered stream; interval adapts to battery (2.5s normal / 9s if `<20%`).
  - Reads heading (compass, GPS-course fallback), speed (from Position), battery (battery_plus).
  - Starts/stops the Android foreground service (persistent notification) around sharing.
- **`RideLocationService`** — Firebase Realtime Database:
  - `startSharing(rideId, Stream<RidePosition>)` — writes `locations/{rideId}/{uid}` on each tick; sets presence online + registers `onDisconnect`.
  - `stopSharing(rideId)` — sets presence offline, cancels writes.
  - `Stream<List<MemberLocation>> watchLocations(rideId)` — merges `locations` + `presence` children into member locations.

### Models
- `RidePosition{ lat, lng, speed, heading, battery }` — a single local reading.
- `MemberLocation{ uid, lat, lng, speed, heading, battery, updatedAt, online, lastSeen }` — a remote member's live state; `speedKmh`, `lastSeenText` helpers.

### Module `modules/ride_map/`
- `ride_map_view` + `_controller` + `_binding` (arg: `rideId`).
- **flutter_map** `MapController`; `TileLayer` with `AppConstants.osmTileUrl` + `userAgentPackageName`; **`RichAttributionWidget`** with the "© OpenStreetMap contributors" link (OSM policy).
- **Markers:** one per member from `watchLocations`. Custom pin = colored teardrop + initial + heading arrow + a small speed label. Position tweened between updates for smooth movement (animate lat/lng over ~600ms).
- **Recenter FAB** → animates camera to my latest position.
- **Members bottom-sheet** → list: color dot, name, speed km/h, battery%, "Online" / "last seen 3m ago"; tap → camera to that member.
- **Empty/error states:** GPS off → "Turn on location" + open-settings; permission denied → settings deep-link; only me on map → "Waiting for friends to share location".

### Entry point & routing
- Ride Detail gains an **"Open live map"** FilledButton (shown when ride active). `Routes.rideMap` registered with `RideMapBinding`, `arguments: rideId`.

### Battery-aware logic
`battery_plus` level polled at start + on `onBatteryStateChanged`; `<20%` → position interval 9s and the notification text notes battery-saver mode; otherwise 2.5s.

### Native config
- **Android** (`AndroidManifest.xml`): location + `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` + `ACCESS_BACKGROUND_LOCATION` + `POST_NOTIFICATIONS` perms already present (Phase 1). Add geolocator's foreground-service notification config (via `AndroidSettings.foregroundNotificationConfig`). No manifest service block needed — geolocator provides it.
- **iOS** (`Info.plist`): `NSLocation*UsageDescription` + `UIBackgroundModes: location` already present (Phase 1).

### Error handling
GPS disabled, permission denied / permanently-denied (→ `Geolocator.openAppSettings()`), location timeout, RTDB unconfigured (clear message pointing to console), no-internet, empty member list.

## Console prerequisite (BLOCKS running Phase 3)
**Realtime Database must be created**: Firebase Console → Build → Realtime Database → Create database → test mode. Its URL must match `databaseURL` in `firebase_options.dart` (currently the US default `https://ridetogether-nwaytech-default-rtdb.firebaseio.com`; if a different region is chosen, update that one constant).

## Out of scope (later)
- Route polyline / ETA / off-route (Phase 4). Chat (Phase 5). SOS/FCM (Phase 6). Ride history persistence + release builds (Phase 7). Phase 7 will also harden the always-on background robustness; Phase 3 delivers a working foreground-service tracker.

## Quality rules (carried forward)
Clean module structure; compiles/runs; typed friendly errors; battery-aware; OSM attribution present; no Google Maps; `flutter analyze` clean; verify on emulator (mock location) with screenshots.
