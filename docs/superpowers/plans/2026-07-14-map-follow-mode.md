# Live Map Follow Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add continuous "follow" behavior to the live map — tapping a
member follows their live position, the recenter FAB becomes a "follow
me / resume following" toggle, and dragging/pinching the map cancels
following until the user taps recenter again.

**Architecture:** Two new reactive fields (`followTarget`, `isFollowing`)
on `RideMapController`, one new reactive listener that re-centers the map
whenever the followed target's position updates, and one `flutter_map`
`onPositionChanged` callback wired into `MapOptions` in `RideMapView` to
detect user-initiated drags (`hasGesture == true`) and cancel following.
Controller and view changes land together in a single task so the app
compiles and is manually testable after each task.

**Tech Stack:** Flutter, GetX, `flutter_map: ^7.0.2` (`MapController.camera`
gives `MapCamera` with `.zoom`; `PositionCallback = void Function(MapCamera
camera, bool hasGesture)` — verified against the installed package source
at `flutter_map-7.0.2/lib/src/map/options/options.dart`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-map-follow-mode-design.md`.
- Do not modify `RideLocationService`, `LocationService`, `RoutingService`,
  `ChatService`, `SosService`, `RideService`, or any model/RTDB path.
- Do not change the SOS FAB, members bottom sheet content/layout, routing,
  destination marker, or chat unread badge — only the member-tap handler's
  effect and the recenter FAB's behavior/visual state change.
- Fixed zoom level snapped-to on follow-start (self or member) is `16`.
- After every task: run `flutter analyze` (expect no new warnings/errors)
  and `flutter test` (expect all existing tests still pass — this feature
  has no automated widget/unit test since `MapController`/`flutter_map`
  camera behavior isn't unit-testable without a real map surface; verified
  manually on-device instead, consistent with prior map-feature phases).
- This project is not a git repository (confirmed) — skip any `git commit`
  steps; just leave changes on disk after each task's verification passes.

---

## File Structure

Modified files only, no new files:
- `lib/modules/ride_map/ride_map_controller.dart` — add `followTarget`,
  `isFollowing`, a follow-position listener, rewrite `recenter()`, replace
  `focusMember()` with `followMember(String uid)`, add `onMapDragged()`.
- `lib/modules/ride_map/ride_map_view.dart` — wire
  `MapOptions.onPositionChanged`, update the member-tap handler in
  `_showMembers`, restyle the recenter FAB based on `isFollowing`.

---

### Task 1: Follow-mode state + controller behavior

**Files:**
- Modify: `lib/modules/ride_map/ride_map_controller.dart`

**Interfaces:**
- Produces: `Rxn<String> followTarget` (`null` = follow self; a `uid`
  string = follow that member).
- Produces: `RxBool isFollowing` (default `true`).
- Produces: `void recenter()` — resumes following `followTarget`'s current
  value (unchanged signature/name, new behavior).
- Produces: `void followMember(MemberLocation m)` — replaces the old
  `focusMember(MemberLocation m)`; starts following that member.
- Produces: `void onMapDragged()` — call this when the user drags/pinches
  the map; sets `isFollowing.value = false`.
- Consumes (Task 2 wires these into the view): `followTarget`,
  `isFollowing`, `recenter()`, `followMember()`, `onMapDragged()`.

- [ ] **Step 1: Add the two new reactive fields**

Edit `lib/modules/ride_map/ride_map_controller.dart`. Add after the
existing `final RxInt unread = 0.obs;` line:

```dart
  // --- Follow mode ---
  /// null = following my own location; a uid = following that member.
  final Rxn<String> followTarget = Rxn<String>();
  final RxBool isFollowing = true.obs;
```

- [ ] **Step 2: Add the follow-position helper and follow-start helper**

Add these two private methods directly above the existing `recenter()`
method (so they sit next to the code they support):

```dart
  LatLng? _followTargetPosition() {
    final String? target = followTarget.value;
    if (target == null) return myLatLng.value;
    for (final MemberLocation m in members) {
      if (m.uid == target) return LatLng(m.lat, m.lng);
    }
    return null;
  }

  void _startFollowing({String? target}) {
    followTarget.value = target;
    isFollowing.value = true;
    final LatLng? pos = _followTargetPosition();
    if (pos != null) mapController.move(pos, 16);
  }

  void _followIfActive() {
    if (!isFollowing.value) return;
    final LatLng? pos = _followTargetPosition();
    if (pos != null) {
      mapController.move(pos, mapController.camera.zoom);
    }
  }
```

- [ ] **Step 3: Replace `recenter()` and `focusMember()`**

Replace the existing:

```dart
  void recenter() {
    final LatLng? me = myLatLng.value;
    if (me != null) mapController.move(me, 15);
  }

  void focusMember(MemberLocation m) =>
      mapController.move(LatLng(m.lat, m.lng), 16);
```

with:

```dart
  /// Recenter FAB: resume following the last target (self, or a member if
  /// one was previously selected).
  void recenter() => _startFollowing(target: followTarget.value);

  /// Members list tap: start following this specific member.
  void followMember(MemberLocation m) => _startFollowing(target: m.uid);

  /// Called when the user drags/pinches the map — stops auto-follow so we
  /// don't fight their gesture. The recenter FAB reappears in its
  /// actionable state; tapping it resumes following [followTarget].
  void onMapDragged() => isFollowing.value = false;
```

- [ ] **Step 4: Add the reactive follow listeners in `_start()`**

In `_start()`, find the existing block:

```dart
    // Member routes: recompute when a member moves ≥100m.
    ever<List<MemberLocation>>(members, (List<MemberLocation> list) {
      for (final MemberLocation m in list) {
        if (m.uid == uid) continue;
        _maybeRouteMember(m);
      }
    });

    ready.value = true;
```

and insert the two new follow listeners between the existing `ever` block
and `ready.value = true;`:

```dart
    // Member routes: recompute when a member moves ≥100m.
    ever<List<MemberLocation>>(members, (List<MemberLocation> list) {
      for (final MemberLocation m in list) {
        if (m.uid == uid) continue;
        _maybeRouteMember(m);
      }
    });

    // Follow mode: re-center on the target whenever its position updates,
    // but only while actively following (stops as soon as the user drags).
    ever<LatLng?>(myLatLng, (_) => _followIfActive());
    ever<List<MemberLocation>>(members, (_) => _followIfActive());

    ready.value = true;
```

- [ ] **Step 5: Update the doc comment on the class (optional context, not
  behavior)**

No doc comment currently exists on `RideMapController` — skip; nothing to
update.

- [ ] **Step 6: Run analyze**

Run: `flutter analyze`
Expected: **one error is expected and acceptable at this point**:
`ride_map_view.dart` still calls `controller.focusMember(m)`, which no
longer exists. Confirm the *only* new analyzer error is exactly this
undefined-method error in `ride_map_view.dart` — if there are any other
new errors/warnings, fix them before proceeding. This one error is
resolved in Task 2, Step 1 below (both tasks together leave the repo
green; this is the one intentional exception to "every task ends green,"
called out explicitly because splitting controller/view further would
require a temporary compatibility shim with no other purpose).

- [ ] **Step 7: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass (this task touches no code any existing
test imports; the `ride_map_view.dart` compile error does not affect
`flutter test` unless a test imports that file — confirm none do via
`grep -rl "ride_map_view" test/`, expected: no matches).

---

### Task 2: Wire follow mode into `RideMapView`

**Files:**
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Consumes: `controller.followTarget`, `controller.isFollowing`,
  `controller.recenter()`, `controller.followMember(MemberLocation)`,
  `controller.onMapDragged()` (all from Task 1).

- [ ] **Step 1: Update the member-tap handler in `_showMembers`**

Replace:

```dart
                    onTap: () {
                      Get.back();
                      controller.focusMember(m);
                    },
```

with:

```dart
                    onTap: () {
                      Get.back();
                      controller.followMember(m);
                    },
```

- [ ] **Step 2: Wire `onPositionChanged` on the `FlutterMap`**

In the `build` method, find:

```dart
            FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(initialCenter: center, initialZoom: 14),
              children: <Widget>[
```

and replace with:

```dart
            FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onPositionChanged: (MapCamera camera, bool hasGesture) {
                  if (hasGesture) controller.onMapDragged();
                },
              ),
              children: <Widget>[
```

`MapCamera` is exported by `package:flutter_map/flutter_map.dart`, which
this file already imports — no new import needed.

- [ ] **Step 3: Restyle the recenter FAB based on `isFollowing`**

Replace:

```dart
                  Positioned(
                    right: 16,
                    bottom: 96,
                    child: FloatingActionButton(
                      heroTag: 'recenter',
                      onPressed: controller.recenter,
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),
```

with:

```dart
                  Positioned(
                    right: 16,
                    bottom: 96,
                    child: Obx(
                      () => FloatingActionButton(
                        heroTag: 'recenter',
                        backgroundColor: controller.isFollowing.value
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        foregroundColor: controller.isFollowing.value
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                        onPressed: controller.recenter,
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  ),
```

Passing `null` for `backgroundColor`/`foregroundColor` falls back to the
app's themed `FloatingActionButtonThemeData` (already set in `AppTheme`),
so the "not following" state looks exactly like it does today.

- [ ] **Step 4: Run analyze**

Run: `flutter analyze`
Expected: no issues at all now — this resolves the one expected error from
Task 1, Step 6.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: all existing tests pass.

- [ ] **Step 6: Manual on-device verification**

No automated test covers map-camera behavior in this codebase. Verify by
hand with 2 devices in the same active ride, both on the live map screen:

1. Open the live map — confirm it centers on your own location at zoom 16
   (matches `isFollowing` defaulting to `true`, `followTarget` defaulting
   to `null`).
2. Confirm the recenter FAB shows the "active" (primary-colored) style
   immediately on open.
3. Open the members sheet, tap the other member — sheet closes, map pans
   to their marker at zoom 16, and the recenter FAB stays in its "active"
   style.
4. Have the other device change position (walk/simulate movement) — the
   map should keep panning to follow them automatically, without you
   touching the screen.
5. Drag the map yourself — the recenter FAB should switch to its default
   (non-primary) style immediately.
6. Tap the recenter FAB — the map should snap back to zoom 16 centered on
   the member you were following before the drag (not on yourself),
   confirming `followTarget` was preserved across the drag.
7. Tap recenter again after having tapped nothing else — should stay on
   the same member (idempotent).
8. As a final check, from the members sheet tap yourself ("You") if
   listed, or drag then tap recenter with no member ever selected on a
   fresh screen open — confirm self-follow still works via the same path.

Report back whether all 8 checks pass; do not mark this task complete
until they do.
