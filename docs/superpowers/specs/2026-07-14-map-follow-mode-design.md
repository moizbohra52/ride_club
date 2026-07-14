# Live Map Follow Mode — Design Spec

Date: 2026-07-14

## Goal

On the live map screen (`RideMapView`/`RideMapController`), let the user tap a
member in the members list and have the map continuously follow that
member's live position (auto-pan as they move), not just jump to them once.
Extend the same "follow" concept to the existing recenter button so it
means "follow me." Following stops the moment the user manually drags or
pinches the map, at which point the existing recenter FAB becomes the way
to resume following (the last target — self or a specific member).

This is a behavior change confined to `RideMapController` and
`RideMapView` — no new screens, no service/model changes, no changes to
how location data is written or read from RTDB.

## Current behavior (for contrast)

- `RideMapController.recenter()` — one-shot `mapController.move(me, 15)`,
  no ongoing follow.
- `RideMapView._showMembers` → tap a member → `Get.back()` then
  `controller.focusMember(m)` → one-shot `mapController.move(memberLatLng, 16)`.
- The recenter FAB is always visible, in the same visual state, regardless
  of anything the map is doing.

## New state (`RideMapController`)

- `Rxn<String> followTarget` — `null` means "follow me"; a member's `uid`
  means "follow that member." This is the *last selected* target,
  independent of whether following is currently active.
- `RxBool isFollowing` — whether the map is actively auto-panning to
  `followTarget`'s position right now.

Both start as `followTarget = null`, `isFollowing = true` — on screen open,
the map follows the user's own location by default (matches current
behavior of centering on `myLatLng` at open).

## Behavior changes

1. **On follow start** (whenever `isFollowing` transitions to `true` for a
   new or resumed target): snap zoom to a fixed level (16) and center on
   the target's current position immediately, via
   `mapController.move(point, 16)`.

2. **While following** (`isFollowing == true`): a reactive listener watches
   the target's position —
   - target `null` (me) → listen to `myLatLng`
   - target a `uid` → listen to that member's entry in `members`
   and calls `mapController.move(point, mapController.camera.zoom)` on each
   update (preserves whatever zoom the user is currently at during ongoing
   follow — only the *start* of a follow snaps zoom to 16, per the
   approved design).

3. **Tapping a member in the members list**: set
   `followTarget.value = member.uid`, `isFollowing.value = true`. Do not
   close the members sheet before this (existing `Get.back()` call stays;
   order doesn't matter since this is just state).

4. **Tapping the recenter FAB**: set `isFollowing.value = true` without
   changing `followTarget` — i.e. resume following whatever the last
   target was (self, if none was ever picked, or the last-tapped member).

5. **User drags or pinches the map**: set `isFollowing.value = false`.
   Detected via `MapOptions.onPositionChanged(camera, hasGesture)` —
   `hasGesture == true` means the change came from user touch input, not
   from our own `mapController.move()` calls (those report
   `hasGesture == false`). Only react to `hasGesture == true`.

6. **Recenter FAB visual state**: reuse the existing single FAB (no new
   button). When `isFollowing == true`, render it in an active/highlighted
   state (filled with `scheme.primary` background) so the user can see
   auto-follow is on. When `isFollowing == false`, render it in its current
   default style — this is the actionable "tap to resume following" state.

## What does NOT change

- SOS FAB — already on the map (bottom-left), already opens the same
  confirm flow. No changes requested or made here.
- Members bottom sheet content/layout — unchanged, only its tap handler's
  effect changes (state update instead of one-shot move).
- Routing, chat unread badge, SOS banner, destination marker — untouched.
- No changes to `RideLocationService`, `LocationService`, or any RTDB
  read/write path — this is pure map-camera/UI behavior.

## Edge cases

- **Followed member goes offline / stops sending updates:** following
  simply stays parked at their last known position (no special handling
  needed — this falls out naturally from "listen to their position, do
  nothing if it doesn't change").
- **Followed member leaves `members` list** (e.g. ride ends, they leave):
  the reactive listener finds no matching entry; follow silently does
  nothing further until the user picks a new target or taps recenter
  (which falls back to self if `followTarget` no longer resolves to a
  real member — see Task-level handling in the plan).
- **My own location follow** while `followTarget == null`: same mechanism,
  listens to `myLatLng` instead of a member lookup.

## Testing / verification

- `flutter analyze` clean.
- Existing tests untouched and passing (this touches only
  `RideMapController`/`RideMapView`, which have no existing unit tests —
  GetX controller logic here depends on `flutter_map`'s `MapController`
  and RTDB streams, so it's verified by on-device manual check, consistent
  with how Phase 3/4 map behavior was verified previously).
- Manual on-device check: open live map with 2 devices in the same ride,
  confirm (a) default self-follow on open, (b) tapping a member switches
  follow to them and the map pans as they move, (c) dragging the map stops
  follow and the recenter FAB shows its default state, (d) tapping recenter
  resumes following the last target at fixed zoom.

## Risk

Low — isolated to one controller and one view file, no data-layer changes.
