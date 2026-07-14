# Live Map Navigation-Style Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While follow mode is active (self or a member), rotate the map so
the followed target's direction of travel points up, and offset the
camera so the followed marker sits in the lower third of the screen
instead of dead-center. Keep all markers visually upright by
counter-rotating them against the map's rotation.

**Architecture:** `RideMapController` gains `myHeading` (mirrors
`myLatLng`, sourced from the same position stream) and a
`_cameraTargetFor(...)` helper that computes an offset "camera center"
point behind the followed target using `latlong2`'s `Distance.offset`.
`_followIfActive`/`_startFollowing` switch from `mapController.move(...)`
to `mapController.moveAndRotate(...)`. `RideMapView._markers()` wraps each
marker's child in `Transform.rotate` using
`controller.mapController.camera.rotation` to cancel the map's rotation.

**Tech Stack:** Flutter, GetX, `flutter_map: ^7.0.2`
(`MapController.moveAndRotate(LatLng center, double zoom, double degree,
{String? id})`, `MapCamera.rotation` in degrees — verified against
installed package source), `latlong2: 0.9.1`
(`Distance.offset(LatLng from, num distanceInMeter, num bearing)` →
`LatLng`, bearing in degrees — verified against installed package
source).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-map-navigation-rotation-design.md`.
- Do not modify `RideLocationService`, `LocationService` (beyond reading
  its existing `positionStream()` output — no changes to that service
  itself), `RoutingService`, `ChatService`, `SosService`, `RideService`,
  or any RTDB/Firestore schema. `MemberLocation.heading` and
  `RidePosition.heading` already exist and are already populated — no
  model changes.
- Do not change follow-target selection logic (member tap, recenter FAB
  semantics) from the prior follow-mode feature — only what happens
  *while* following (rotation + offset) changes.
- Camera offset distance behind the target is a fixed `120` meters.
- After every task: run `flutter analyze` (expect no new warnings/errors)
  and `flutter test` (expect all existing tests still pass).
- This project is not a git repository — skip any `git commit` steps;
  leave changes on disk after each task's verification passes.

---

## File Structure

Modified files only, no new files:
- `lib/modules/ride_map/ride_map_controller.dart` — add `myHeading`,
  a heading-lookup helper, a camera-offset helper, switch
  `_startFollowing`/`_followIfActive` to `moveAndRotate`.
- `lib/modules/ride_map/ride_map_view.dart` — counter-rotate marker
  children in `_markers()`.

---

### Task 1: Track heading + compute the offset camera center

**Files:**
- Modify: `lib/modules/ride_map/ride_map_controller.dart`

**Interfaces:**
- Produces: `RxDouble myHeading` (degrees, default `0.0`).
- Produces: `double? _followTargetHeading()` — mirrors
  `_followTargetPosition()`: `null` target → `myHeading.value`; a member
  uid → that member's `MemberLocation.heading`, or `null` if the member
  isn't currently in `members`.
- Produces: `LatLng _cameraCenterBehind(LatLng target, double heading)` —
  returns a point 120m behind `target` along the reverse of `heading`
  (i.e. `Distance().offset(target, 120, heading + 180)`), so that
  centering the map on this returned point visually places `target` in
  the lower third of the screen once rotated to face `heading`.
- Consumes (Task 2 uses these): `myHeading`, `_followTargetHeading()`,
  `_cameraCenterBehind(...)`.

- [ ] **Step 1: Add the `myHeading` field**

Edit `lib/modules/ride_map/ride_map_controller.dart`. Add directly after
the existing `final Rxn<LatLng> myLatLng = Rxn<LatLng>();` line:

```dart
  final RxDouble myHeading = 0.0.obs;
```

- [ ] **Step 2: Populate `myHeading` alongside `myLatLng`**

Find this line in `_start()`:

```dart
    _loc.positionStream().listen((p) => myLatLng.value = LatLng(p.lat, p.lng));
```

Replace it with:

```dart
    _loc.positionStream().listen((p) {
      myLatLng.value = LatLng(p.lat, p.lng);
      myHeading.value = p.heading;
    });
```

- [ ] **Step 3: Add `_followTargetHeading` and `_cameraCenterBehind`**

Add these two methods directly after the existing
`_followTargetPosition()` method:

```dart
  double? _followTargetHeading() {
    final String? target = followTarget.value;
    if (target == null) return myHeading.value;
    for (final MemberLocation m in members) {
      if (m.uid == target) return m.heading;
    }
    return null;
  }

  LatLng _cameraCenterBehind(LatLng target, double heading) {
    return _dist.offset(target, 120, heading + 180);
  }
```

`_dist` is the existing `final Distance _dist = const Distance();` field
already declared in this class (used by `_meters`/`_distanceToRoute`) —
no new field needed.

- [ ] **Step 4: Run analyze**

Run: `flutter analyze`
Expected: no new issues (these new methods aren't called anywhere yet,
which is fine — Task 2 wires them in; confirm no "unused element"
warnings, since Dart doesn't warn on unused private instance methods the
way it does unused private top-level functions/variables — if a warning
does appear, that's unexpected and should be investigated, not
suppressed).

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass (no test imports this controller).

---

### Task 2: Rotate-and-move while following

**Files:**
- Modify: `lib/modules/ride_map/ride_map_controller.dart`

**Interfaces:**
- Consumes: `myHeading`, `_followTargetHeading()`,
  `_cameraCenterBehind(...)` (Task 1).
- Produces: same public API (`_startFollowing`, `_followIfActive`,
  `recenter`, `followMember`, `onMapDragged` all keep their existing
  names/signatures) — only their internals change to rotate+offset.

- [ ] **Step 1: Replace `_startFollowing`'s camera call**

Find:

```dart
  void _startFollowing({String? target}) {
    followTarget.value = target;
    isFollowing.value = true;
    final LatLng? pos = _followTargetPosition();
    if (pos != null) mapController.move(pos, 16);
  }
```

Replace with:

```dart
  void _startFollowing({String? target}) {
    followTarget.value = target;
    isFollowing.value = true;
    final LatLng? pos = _followTargetPosition();
    if (pos == null) return;
    final double heading = _followTargetHeading() ?? 0;
    mapController.moveAndRotate(
      _cameraCenterBehind(pos, heading),
      16,
      -heading,
    );
  }
```

- [ ] **Step 2: Replace `_followIfActive`'s camera call**

Find:

```dart
  void _followIfActive() {
    if (!isFollowing.value) return;
    final LatLng? pos = _followTargetPosition();
    if (pos != null) {
      mapController.move(pos, mapController.camera.zoom);
    }
  }
```

Replace with:

```dart
  void _followIfActive() {
    if (!isFollowing.value) return;
    final LatLng? pos = _followTargetPosition();
    if (pos == null) return;
    final double heading = _followTargetHeading() ?? 0;
    mapController.moveAndRotate(
      _cameraCenterBehind(pos, heading),
      mapController.camera.zoom,
      -heading,
    );
  }
```

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass.

---

### Task 3: Counter-rotate marker children

**Files:**
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Consumes: `controller.mapController.camera.rotation` (degrees, from
  `flutter_map`).

- [ ] **Step 1: Wrap marker children in `Transform.rotate`**

Find the `_markers()` method:

```dart
  List<Marker> _markers() {
    final List<Marker> markers = <Marker>[];

    // Always show your own location as a marker
    final LatLng? me = controller.myLatLng.value;
    if (me != null) {
      markers.add(
        Marker(
          key: const ValueKey('my_location'),
          point: me,
          width: 48,
          height: 48,
          child: Icon(
            Icons.my_location_rounded,
            color: AppColors.seed,
            size: 32,
          ),
        ),
      );
    }

    for (final MemberLocation m in controller.members) {
      if (m.uid == controller.uid) continue; // Don't duplicate the "me" marker
      markers.add(
        Marker(
          key: ValueKey<String>(m.uid),
          point: LatLng(m.lat, m.lng),
          width: 80,
          height: 80,
          child: _MemberPin(
            color: AppColors.memberColorForKey(m.uid),
            heading: m.heading,
            speedKmh: m.speedKmh,
            isMe: m.uid == controller.uid,
          ),
        ),
      );
    }
```

Replace it with (only the two marker `child:` values change, wrapped in
`Transform.rotate`; everything else — the destination marker below this
block, and the method's closing lines — is unchanged and stays as-is):

```dart
  List<Marker> _markers() {
    final List<Marker> markers = <Marker>[];
    final double counterRotation = -controller.mapController.camera.rotation *
        (math.pi / 180);

    // Always show your own location as a marker
    final LatLng? me = controller.myLatLng.value;
    if (me != null) {
      markers.add(
        Marker(
          key: const ValueKey('my_location'),
          point: me,
          width: 48,
          height: 48,
          child: Transform.rotate(
            angle: counterRotation,
            child: Icon(
              Icons.my_location_rounded,
              color: AppColors.seed,
              size: 32,
            ),
          ),
        ),
      );
    }

    for (final MemberLocation m in controller.members) {
      if (m.uid == controller.uid) continue; // Don't duplicate the "me" marker
      markers.add(
        Marker(
          key: ValueKey<String>(m.uid),
          point: LatLng(m.lat, m.lng),
          width: 80,
          height: 80,
          child: Transform.rotate(
            angle: counterRotation,
            child: _MemberPin(
              color: AppColors.memberColorForKey(m.uid),
              heading: m.heading,
              speedKmh: m.speedKmh,
              isMe: m.uid == controller.uid,
            ),
          ),
        ),
      );
    }
```

`math` is already imported in this file as `import 'dart:math' as math;`
(used by `_PinPainter`) — no new import needed.

- [ ] **Step 2: Run analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass.

- [ ] **Step 4: Manual on-device verification**

No automated test covers map-camera rotation in this codebase. Verify by
hand with 2 devices in the same active ride, both on the live map screen,
physically moving (walking or driving) so a real heading is produced:

1. Start following yourself (default on open) and walk/move — the map
   should rotate so your direction of travel points up, and your blue dot
   should sit in the lower third of the screen, not dead-center.
2. Confirm your own location icon stays upright (not tilted) as the map
   rotates under it.
3. From the members sheet, tap the other member to follow them — as they
   move, the map should rotate to face their direction of travel, and
   their pin should sit in the lower third.
4. Confirm the followed member's pin (and its internal heading-arrow from
   `_PinPainter`) stays upright and the arrow still visibly points in
   their direction of travel relative to the rotated map.
5. Drag the map — rotation/follow should stop (per the existing
   drag-cancels-follow behavior); tap recenter — following (with
   rotation) should resume on the last target.

Report back whether all 5 checks pass; do not mark this task complete
until they do.
