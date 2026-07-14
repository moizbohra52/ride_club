# Live Map — Google-Maps-Style Enhancements Design Spec

Date: 2026-07-14

## Goal

Make the live map feel like Google Maps and polish it: smooth animated
camera, on-screen zoom + fit-all controls, photo-based member pins that
open detail on tap, dark-mode map tiles, and a polished route (thicker
gradient line + direction arrows).

This builds on the existing live map (drag/pinch/rotate gestures, follow
mode, navigation-style rotation, routes, members/detail sheets, SOS) —
none of that is removed; these are additive enhancements plus a swap of
the raw `MapController` for an animated one.

## Current state (unchanged foundations)

- Gestures: flutter_map defaults (drag, pinch-zoom, two-finger rotate) —
  `MapOptions` currently sets no explicit `interactionOptions`.
- Follow mode: `followTarget`/`isFollowing`, navigation rotation via
  `mapController.moveAndRotate(...)` on each GPS tick (~2.5s) and on
  follow-start.
- Routes: `_routePolylines()` draws member routes (faint) + my route
  (bold `AppColors.seed`, 5px), only when a destination is set.
- Markers: `_MemberPin` (colored teardrop + heading arrow + speed label);
  my-location is a plain icon.
- Tiles: `AppConstants.osmTileUrl` (standard OSM light) always.
- `RideMapController.rideMemberFor(uid)` returns the Firestore
  `RideMember` (name, photoUrl, color, role) — available for photo pins.

## Changes

### 1. Smooth animated camera (`flutter_map_animations`)

Add dependency `flutter_map_animations` (compatible with
`flutter_map ^7.0.2`). Replace `RideMapController.mapController`
(`MapController`) with an `AnimatedMapController` (which wraps a
`MapController` and requires a `TickerProvider`).

Because `AnimatedMapController` needs a `vsync`, and `GetxController`
provides `GetSingleTickerProviderStateMixin`, mix that into
`RideMapController` and construct the animated controller in `onInit`
(not as a field initializer, since it needs `this` as vsync).

All camera moves become animated:
- `_startFollowing`, `_followIfActive` → `animatedMapController
  .animateTo(dest: center, zoom: z, rotation: -heading)`.
- New zoom buttons → `animateTo(zoom: currentZoom ± 1)`.
- New fit-all → `animatedMapController.animatedFitCamera(cameraFit: ...)`.

`AnimatedMapController.animateTo` cancels any in-flight animation before
starting a new one, so overlapping GPS-tick follows don't stack — each
tick smoothly retargets. Follow animation duration is kept short
(~600ms) so it completes well within the ~2.5s tick interval.

The raw `MapController` underneath is exposed by
`AnimatedMapController.mapController`; `RideMapView` passes THAT to
`FlutterMap(mapController: ...)`, and reads `.camera` from it (for the
marker counter-rotation). Everywhere the view/controller currently uses
`controller.mapController.camera` / `.move` / `.moveAndRotate`, it
switches to the animated controller's API or the underlying
`.mapController.camera` for reads.

### 2. Zoom + fit-all controls

A vertical control stack on the right edge (above the recenter FAB):
- `+` button → zoom in one level (animated).
- `−` button → zoom out one level (animated).
- `⤢` (fit-all) button → compute a `LatLngBounds` covering all member
  locations + my location + destination (whichever exist), and
  `animatedFitCamera` to it with padding. Fit-all is a one-shot overview;
  it does NOT change follow state beyond the drag-like effect (calling it
  sets `isFollowing = false` so the auto-follow loop doesn't immediately
  yank the camera back — same as a manual gesture).

If only one point exists (just me, no members/destination), fit-all
falls back to a plain animated `animateTo` on that point at zoom 16.

### 3. Photo-based member pins

Rebuild `_MemberPin` into a Google-Maps-style pin:
- A circular avatar (radius ~20) showing the member's profile photo
  (`CachedNetworkImageProvider`), ringed in the member's color.
- Fallback when no photo: the member's colored initial (first letter),
  same style as the members list / detail sheet.
- The heading arrow stays (small triangle below/around the avatar
  pointing in `heading`), and the speed label stays.
- The pin needs the member's `photoUrl` + `name`, looked up via
  `controller.rideMemberFor(m.uid)` in `_markers()` and passed into
  `_MemberPin`.
- Marker tap opens the existing `showMemberDetail(...)` sheet (same call
  as the members-sheet info icon: `member: resolved`, `live: m`,
  `route: controller.routeFor(m.uid)`). Since a flutter_map `Marker`'s
  child is a normal widget, wrap the pin in a `GestureDetector`/`InkWell`
  for the tap.
- My-location marker also becomes a photo pin (my own `RideMember` via
  `rideMemberFor(uid)`) with a distinct ring, replacing the plain icon.

Counter-rotation (from the navigation-rotation feature) still wraps every
marker child so pins stay upright.

### 4. Dark-mode map tiles

Add to `AppConstants`:
- `osmTileUrlDark` = CARTO dark-matter raster tiles
  (`https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png`) — free,
  OSM-based, requires CARTO + OSM attribution.

In `RideMapView`, pick the tile URL by `Theme.of(context).brightness`:
light → `osmTileUrl`, dark → `osmTileUrlDark`. Update the
`RichAttributionWidget` to also credit CARTO when dark tiles are shown.

### 5. Route polish

In `_routePolylines()`:
- My route: draw as two stacked polylines — a wider translucent "glow"
  underneath (10px, `AppColors.seed` at low alpha) and the main line on
  top (6px, solid `AppColors.seed`). Member routes stay single faint
  lines.
- Direction arrows: add small arrow markers evenly spaced along the
  route toward the destination. Implement as extra `Marker`s in
  `_markers()` computed from `myRoute.points` — pick every Nth point,
  orient a small arrow icon along the segment bearing. Keep the count
  low (e.g. ~1 arrow per ~10 route points) to avoid clutter and cost.
  Arrows only for MY route (not every member's, to avoid clutter).

## Non-goals

- No change to how routes are computed (`RoutingService`/OSRM) or how
  location is shared (`RideLocationService`/RTDB).
- No change to follow-target selection, SOS, chat, or the members/detail
  sheets' content.
- No offline tile caching, no custom map-style JSON (raster tiles only).

## Risks

- **Medium:** swapping `MapController` → `AnimatedMapController` touches
  every camera call site; a missed call site or a vsync/lifecycle mistake
  could break follow/rotation. Mitigated by doing it as its own task with
  analyze+manual check before layering the rest.
- **Low-medium:** overlapping follow animations feeling jerky — mitigated
  by short duration + animateTo's built-in cancellation; tunable
  on-device.
- **Low:** CARTO tile URL/attribution — must keep attribution visible to
  respect their free-tier terms.

## Testing / verification

- `flutter analyze` clean; existing tests pass (no unit tests cover
  map-camera/flutter_map behavior — verified on-device, per prior map
  features).
- Manual on-device: smooth animated recenter/member-follow/zoom/fit;
  photo pins render (+ initial fallback) and open detail on tap; dark
  theme shows dark tiles; route shows thick gradient line + direction
  arrows; drag still cancels follow; fit-all frames everyone.

## Task decomposition (for the plan)

1. Add `flutter_map_animations`, swap to `AnimatedMapController`, keep
   behavior identical (animated instead of instant). Verify follow +
   rotation still work.
2. Zoom + fit-all control stack.
3. Photo-based member pins + tap-to-detail (incl. my-location pin).
4. Dark-mode tiles.
5. Route polish (gradient line + direction arrows).
