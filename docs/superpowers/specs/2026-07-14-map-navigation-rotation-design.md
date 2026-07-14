# Live Map Navigation-Style Rotation — Design Spec

Date: 2026-07-14

## Goal

While follow mode is active (self or a member — built in the prior
"follow mode" feature), the map should rotate so the followed target's
direction of travel always points up (like turn-by-turn navigation apps),
and the followed marker should sit in the lower-third of the screen rather
than dead-center, so more of the road ahead is visible.

This extends `RideMapController`'s existing follow mechanism
(`followTarget`, `isFollowing`, `_followIfActive`) — it does not replace
it. Follow mode without rotation is not a separate mode; rotation is
simply part of what "following" now means, for both self and members.

## Current state

- `RideMapController._followIfActive()` calls
  `mapController.move(pos, mapController.camera.zoom)` on every position
  update while `isFollowing == true` — no rotation, target centered exactly.
- `RideMapController.myLatLng` is `Rxn<LatLng>`, populated from
  `LocationService.positionStream()` — the stream's `RidePosition.heading`
  (already computed: compass-first, GPS-course-fallback, see
  `LocationService.positionStream()`) is currently dropped; only lat/lng
  is kept.
- `MemberLocation.heading` (RTDB) already carries each member's heading.
- `flutter_map: ^7.0.2` exposes `MapController.rotate(degree)` and
  `MapController.moveAndRotate(point, zoom, degree)` — verified against
  the installed package source.
- Markers (`_MemberPin`/my-location icon) are drawn in a `MarkerLayer`
  whose children do NOT automatically counter-rotate when the map camera
  rotates — flutter_map rotates the whole layer, so marker children rotate
  visually with the map unless explicitly counter-rotated.

## Changes

### 1. Track heading alongside position

- Add `final RxDouble myHeading = 0.0.obs;` to `RideMapController`.
  Update it in the same `positionStream().listen(...)` callback that
  currently sets `myLatLng.value`.
- `MemberLocation` already has `.heading` — no model change needed there.

### 2. Rotate-and-move while following

Replace the plain `move()` call in `_followIfActive()` (and the
follow-start snap in `_startFollowing()`) with a combined
move+rotate that:
1. Computes the current target's heading (self: `myHeading.value`;
   member: `MemberLocation.heading` for the followed uid).
2. Computes a "camera center" point offset from the target's actual
   position — shifted *behind* the target (opposite the heading
   direction) by a small fixed distance, so that after centering the map
   on this offset point, the actual marker renders in the lower third of
   the screen.
3. Calls `mapController.moveAndRotate(cameraCenter, zoom, -heading)` (the
   negative sign is `flutter_map`'s convention: rotating the map by
   `-heading` degrees makes the direction-of-travel point up).

The offset distance is computed in lat/lng degrees scaled by zoom level,
reusing the existing `Distance` (`latlong2`) helper already imported in
this controller for `_meters`/`_distanceToRoute` — a fixed real-world
offset (e.g. 120m) via `Distance().offset(target, 120, heading)` in the
*opposite* bearing (`heading + 180`).

### 3. Counter-rotate marker children

`RideMapView._markers()` builds `Marker` widgets whose `child` is either
the my-location icon or `_MemberPin`. Wrap each marker's child in
`Transform.rotate(angle: -mapRotationRadians, child: ...)` where
`mapRotationRadians` comes from `controller.mapController.camera.rotation`
(in degrees, converted to radians) — this cancels the map's own rotation
so pins/icons stay visually upright regardless of map orientation.
`_MemberPin`'s own internal heading-arrow (drawn by `_PinPainter`) is
unaffected — it continues to draw the member's direction-of-travel arrow
relative to the now-upright pin, so the combination (map rotated to
travel direction + arrow drawn relative to upright pin) correctly shows
"arrow points up when moving forward, turns as the rider turns."

### 4. Drag interaction stays as designed previously

Dragging/pinching (`onMapDragged`) still sets `isFollowing = false` and
stops the auto-move/rotate loop — the user can freely pan/zoom/rotate by
hand. Tapping recenter resumes following (per the prior feature) and
snaps back into rotation via `_startFollowing`.

## What does NOT change

- Follow-target selection logic (member tap, recenter FAB) — unchanged
  from the prior feature.
- SOS, chat, routing, destination marker — untouched.
- No RTDB/Firestore schema changes — `MemberLocation.heading` already
  exists and is already written by every device via
  `RideLocationService`/`LocationService`.

## Edge cases

- **Heading is 0 / stationary target:** rotation simply doesn't change
  (map stays at whatever orientation it was last rotated to) — this is
  acceptable; a stationary rider doesn't need a "forward" direction.
- **Very first follow-start before any heading is known:** falls back to
  `0` (north-up), same as today's default.

## Testing / verification

- `flutter analyze` clean.
- Existing tests untouched and passing (no unit test covers
  `MapController`/camera rotation — flutter_map camera behavior isn't
  testable without a real map surface, consistent with the prior
  follow-mode feature).
- Manual on-device check with 2 devices in the same active ride: follow
  self while moving (map should rotate to face direction of travel, own
  marker sits lower-third); follow a member while they move (same);
  confirm markers stay upright throughout; confirm the member pin's
  heading-arrow still correctly reflects their direction relative to the
  now-rotated map.

## Risk

Low-medium — the offset/rotation math is new and geometry bugs are easy
to introduce (e.g. sign errors on bearing), but it's isolated to
`RideMapController`/`RideMapView` with no data-layer changes, and testable
by eye on-device.
