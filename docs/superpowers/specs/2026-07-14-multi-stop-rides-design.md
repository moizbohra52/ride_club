# Multi-Stop Rides Design Spec

Date: 2026-07-14

## Goal

Let the host define a ride as an ordered journey — an origin, any number
of intermediate waypoints (reorderable), and a destination (e.g. Indore →
Manawar → Kukshi → Dahi). Compute the full planned driving route once at
create-time, store it on the ride, and show it (with numbered stop pins)
to everyone on the live map. Each member's own live-GPS route continues
unchanged.

## Current state

- `Ride` has one optional `destination` (`RideDestination` = lat/lng/label).
  No origin, no waypoints.
- `RideService.createRide({name, destination})` writes the ride doc +
  host member + rideRef.
- `CreateRideController` has one destination search field (debounced
  Nominatim via `GeoService.searchPlaces`, single `chosen` PlaceResult).
- `RoutingService.route(from, to)` fetches a single-segment OSRM driving
  route through a global serial queue (≥1.2s spacing). OSRM's URL already
  accepts multiple `;`-separated coordinates in one call.
- `RideMapController` computes per-member live routes and draws a
  destination flag pin; `_routePolylines()` draws member + my routes;
  `_markers()` draws member pins + destination flag.
- `polyline_codec.dart` has `decodePolyline` only (no encoder).

## Design

### 1. `RoutingService.routeMulti(List<LatLng> stops)`

New method returning `Future<RouteResult?>`. Builds a `;`-joined
`lng,lat` coordinate string from `stops` (≥2 required; returns null
otherwise) and fetches ONE OSRM driving route through the existing serial
queue + spacing machinery (so group rate stays within fair-use). Parses
the same way `route()` does (decoded polyline points + total distance +
duration). `route(from, to)` stays as-is (used for per-member live
routes).

### 2. Model changes (`Ride`, `RideDestination`)

`RideDestination` unchanged. `Ride` gains (all optional, backward-
compatible):
- `RideDestination? origin`
- `List<RideDestination> waypoints` (ordered; defaults to `const []`)
- `List<LatLng>? plannedRoute` — the OSRM polyline points computed at
  create-time
- `double? plannedDistanceMeters`, `double? plannedDurationSeconds`

Firestore representation (in `toMap`/`fromDoc`):
- `origin`: nested map (same shape as `destination`) or null.
- `waypoints`: array of `{lat,lng,label}` maps (empty array if none).
- `plannedRoute`: array of `{lat,lng}` maps (NOT an encoded string — the
  codec has no encoder, and storing point maps avoids adding one and any
  precision risk). Null/absent if the ride has <2 stops.
- `plannedDistanceMeters`/`plannedDurationSeconds`: numbers or absent.

`fromDoc` must tolerate old docs: missing origin → null, missing
waypoints → `[]`, missing plannedRoute → null. Add a computed getter:
```
List<RideDestination> orderedStops =>
  [ if (origin != null) origin!, ...waypoints, if (destination != null) destination! ]
```
(used for map pins and for computing the planned route).

### 3. `RideService.createRide(...)`

Signature gains `RideDestination? origin`, `List<RideDestination>
waypoints = const []`, `List<LatLng>? plannedRoute`,
`double? plannedDistanceMeters`, `double? plannedDurationSeconds`.
It writes them into the ride doc via the updated `Ride.toMap`. No change
to member/rideRef writes. (The controller computes the route BEFORE
calling this — the service just persists what it's given.)

### 4. Create-ride UI (`CreateRideController` + `create_ride_tab.dart`)

Controller replaces the single `destField`/`chosen`/`suggestions` with:
- An `origin` stop editor.
- An ordered `RxList` of waypoint stop editors.
- A `destination` stop editor.

A "stop editor" is a small helper object bundling a `TextEditingController`,
an `Rxn<PlaceResult> chosen`, an `RxList<PlaceResult> suggestions`, an
`RxBool searching`, and its own debounce timer — so each field searches
independently (reusing the existing debounced-Nominatim logic, factored
into a reusable method keyed by which editor is active). Methods:
`addWaypoint()`, `removeWaypoint(i)`, `reorderWaypoints(oldIndex,
newIndex)`, and per-editor `onSearchChanged`/`choose`.

`create()` gathers the chosen `PlaceResult`s in order (origin, waypoints,
destination — skipping empties), converts to `RideDestination`s, and:
- If `orderedStops.length >= 2`, calls `routeMulti(...)` to compute the
  planned route; on success passes points+distance+duration to
  `createRide`. On failure (null), still creates the ride but without a
  planned route (non-fatal, `UiHelpers.warning`).
- Passes `origin`, `waypoints`, `destination` to `createRide`.

View: an "Origin" search field, a `ReorderableListView` of waypoint rows
(each: search field + drag handle + remove button), an "+ Add stop"
button, then a "Destination" search field. Each field shows its own
suggestion dropdown and "chosen" confirmation chip, matching the current
visual pattern (AppCard/tokens where they fit). All stops optional — an
empty ride (no stops) still creates, exactly as today.

### 5. Live map (`RideMapController` + `ride_map_view.dart`)

- `RideMapController` already streams the `Ride` via `watchRide`; expose
  its `plannedRoute` (and `orderedStops`) to the view. No new OSRM call
  on the map — the planned route comes from the stored ride doc.
- `_routePolylines()`: add the planned route as a distinct polyline —
  a neutral/muted wide line (e.g. `AppColors.ink` at low alpha, dashed
  look via a lighter color) drawn UNDER the live per-member gradient
  routes, so "the plan" reads as background and "where I actually am
  heading" reads as foreground. Member/my live routes unchanged.
- `_markers()`: replace the single destination flag with pins built from
  `ride.orderedStops`: origin → a green "start" pin
  (`Icons.trip_origin`), each waypoint → a numbered pin (1, 2, 3…),
  destination → the existing flag pin. Counter-rotation (navigation
  rotation feature) still applies so pins stay upright.

## Non-goals

- No per-member origins (origin is one shared ride starting point).
- No live re-routing of the planned route — it's fixed at create-time.
- No reordering stops after the ride is created.
- No "arrived at stop" / progress tracking.
- No editing an existing ride's stops (create-time only).

## Testing / verification

- `flutter analyze` clean.
- New unit tests where pure logic allows: `RideService.generateCode`
  test already exists; add a `Ride.fromDoc`/`toMap` round-trip test
  covering origin/waypoints/plannedRoute (including an OLD doc with none
  of them → loads with null/empty). `routeMulti` coord-string building
  can be covered by extending `routing_test.dart` with a fake client
  (mirrors the existing `route` test).
- Manual on-device: create a ride with origin + 2 waypoints +
  destination (search each), reorder waypoints by drag, create → open
  live map → planned route line + numbered pins (origin/1/2/dest) show;
  members' live routes still work; create a ride with NO stops → still
  works; open an OLD pre-existing ride → loads without errors, no planned
  route/pins.

## Risk

Medium — touches the model, service, create UI, and map. Mitigated by
backward-compatible optional fields, storing route points as plain maps
(no new codec), and doing it as separate tasks (routing → model →
service → UI → map) each analyze+test-gated. The create UI (multiple
independent debounced search editors + reorderable list) is the most
intricate piece and gets its own task.
