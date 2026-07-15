# Multi-Stop Rides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Rides become an ordered journey — origin + reorderable waypoints
+ destination — with a full planned OSRM route computed at create-time,
stored on the ride, and shown to everyone on the live map with numbered
stop pins. Per-member live routes stay unchanged.

**Architecture:** Add `routeMulti` to `RoutingService`; extend `Ride`/
Firestore with `origin`/`waypoints`/`plannedRoute` (+ distance/duration);
`createRide` persists them; rebuild create-ride UI with multiple debounced
search editors + a reorderable waypoint list; draw the planned route +
numbered pins on the live map from the stored ride doc.

**Tech Stack:** Flutter, GetX, `flutter_map ^7.0.2`, `latlong2`, OSRM
(multi-coordinate driving route in one call), Nominatim via `GeoService`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-multi-stop-rides-design.md`.
- All new `Ride` fields OPTIONAL & backward-compatible: old Firestore docs
  must load (origin→null, waypoints→`[]`, plannedRoute→null).
- Store `plannedRoute` in Firestore as an array of `{lat,lng}` maps (NOT
  an encoded polyline — no encoder exists; do not add one).
- OSRM public API is rate-limited — the planned route is fetched ONCE at
  create-time via the existing serial queue; the map reads the stored
  route, never re-fetches it.
- Do not change per-member live routing, SOS, chat, follow/rotation, or
  the profile feature.
- After every task: `flutter analyze` (no new issues) + `flutter test`
  (all pass). Not a git repo — skip commits.

---

## File Structure

- Modify `lib/services/routing_service.dart` — add `routeMulti`.
- Modify `lib/models/ride.dart` — origin/waypoints/plannedRoute fields,
  `toMap`/`fromDoc`, `orderedStops` getter.
- Modify `lib/services/ride_service.dart` — `createRide` new params.
- Modify `lib/modules/rides/create_ride_controller.dart` — stop editors,
  add/remove/reorder, compute planned route in `create()`.
- Modify `lib/modules/rides/create_ride_tab.dart` — origin field +
  reorderable waypoints + destination field.
- Modify `lib/modules/ride_map/ride_map_controller.dart` — expose planned
  route + ordered stops from the streamed ride.
- Modify `lib/modules/ride_map/ride_map_view.dart` — planned route line +
  numbered pins.
- Tests: `test/routing_test.dart`, `test/models_test.dart`.

---

### Task 1: `RoutingService.routeMulti`

**Files:**
- Modify: `lib/services/routing_service.dart`
- Test: `test/routing_test.dart`

**Interfaces:**
- Produces: `Future<RouteResult?> routeMulti(List<LatLng> stops, {http.Client? client})`
  — null if `stops.length < 2`; otherwise one OSRM driving route through
  all stops in order, via the existing serial queue.

- [ ] **Step 1: Add the failing test**

Append to `test/routing_test.dart` inside `main()`:

```dart
  test('routeMulti builds a multi-coordinate OSRM request', () async {
    late Uri captured;
    final MockClient mock = MockClient((http.Request req) async {
      captured = req.url;
      return http.Response(
        '{"code":"Ok","routes":[{"distance":100.0,"duration":60.0,'
        '"geometry":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"}]}',
        200,
      );
    });
    final RoutingService svc = RoutingService();
    final RouteResult? r = await svc.routeMulti(
      const <LatLng>[LatLng(1, 2), LatLng(3, 4), LatLng(5, 6)],
      client: mock,
    );
    expect(r, isNotNull);
    // Three ";"-separated "lng,lat" pairs in the path.
    expect(captured.path, contains('2.0,1.0;4.0,3.0;6.0,5.0'));
  });

  test('routeMulti returns null for fewer than two stops', () async {
    final RoutingService svc = RoutingService();
    final RouteResult? r =
        await svc.routeMulti(const <LatLng>[LatLng(1, 2)]);
    expect(r, isNull);
  });
```

- [ ] **Step 2: Run it, expect failure**

Run: `flutter test test/routing_test.dart`
Expected: FAIL — `routeMulti` not defined.

- [ ] **Step 3: Implement `routeMulti`**

Edit `lib/services/routing_service.dart`. Add a public method + a private
multi-fetch, reusing the queue pattern. Insert after the existing
`route(...)` method:

```dart
  Future<RouteResult?> routeMulti(List<LatLng> stops,
      {http.Client? client}) {
    if (stops.length < 2) return Future<RouteResult?>.value(null);
    final Completer<RouteResult?> out = Completer<RouteResult?>();
    _chain = _chain.then((_) async {
      final int sinceMs = DateTime.now().difference(_lastCall).inMilliseconds;
      final int waitMs = _minSpacing.inMilliseconds - sinceMs;
      if (waitMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
      _lastCall = DateTime.now();
      out.complete(await _fetchMulti(stops, client));
    });
    return out.future;
  }

  Future<RouteResult?> _fetchMulti(
      List<LatLng> stops, http.Client? client) async {
    final http.Client c = client ?? http.Client();
    try {
      final String coords = stops
          .map((LatLng s) => '${s.longitude},${s.latitude}')
          .join(';');
      final Uri uri = Uri.parse(
        '${AppConstants.osrmBaseUrl}/route/v1/driving/$coords'
        '?overview=full&geometries=polyline&alternatives=false&steps=false',
      );
      final http.Response res = await c
          .get(uri, headers: <String, String>{
            'User-Agent': AppConstants.httpUserAgent,
          })
          .timeout(AppConstants.networkTimeout);
      if (res.statusCode != 200) {
        Log.e('OSRM multi HTTP ${res.statusCode}');
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final List<dynamic> routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      final Map<String, dynamic> r0 = routes.first as Map<String, dynamic>;
      final List<List<double>> pts =
          decodePolyline(r0['geometry'] as String);
      return RouteResult(
        points: pts.map((p) => LatLng(p[0], p[1])).toList(),
        distanceMeters: (r0['distance'] as num).toDouble(),
        durationSeconds: (r0['duration'] as num).toDouble(),
      );
    } catch (e, s) {
      Log.e('OSRM routeMulti failed', error: e, stack: s);
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
```

- [ ] **Step 4: Run tests, expect pass**

Run: `flutter test test/routing_test.dart`
Expected: PASS (all, including the two new).

- [ ] **Step 5: Analyze + full test**

Run: `flutter analyze` → no new issues. `flutter test` → all pass.

---

### Task 2: `Ride` model — origin / waypoints / plannedRoute

**Files:**
- Modify: `lib/models/ride.dart`
- Test: `test/models_test.dart`

**Interfaces:**
- Produces on `Ride`: `RideDestination? origin`,
  `List<RideDestination> waypoints`, `List<LatLng>? plannedRoute`,
  `double? plannedDistanceMeters`, `double? plannedDurationSeconds`,
  and `List<RideDestination> get orderedStops`.
- `Ride` constructor gains these as optional named params
  (`waypoints` defaults to `const <RideDestination>[]`).

- [ ] **Step 1: Add failing round-trip tests**

Append to `test/models_test.dart` inside `main()`:

```dart
  test('Ride.orderedStops chains origin + waypoints + destination', () {
    const Ride r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
      origin: RideDestination(lat: 1, lng: 1, label: 'Indore'),
      waypoints: <RideDestination>[
        RideDestination(lat: 2, lng: 2, label: 'Manawar'),
        RideDestination(lat: 3, lng: 3, label: 'Kukshi'),
      ],
      destination: RideDestination(lat: 4, lng: 4, label: 'Dahi'),
    );
    expect(r.orderedStops.map((s) => s.label).toList(),
        <String>['Indore', 'Manawar', 'Kukshi', 'Dahi']);
  });

  test('Ride.orderedStops omits nulls (empty ride)', () {
    const Ride r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
    );
    expect(r.orderedStops, isEmpty);
    expect(r.waypoints, isEmpty);
    expect(r.plannedRoute, isNull);
  });

  test('Ride.toMap round-trips origin/waypoints/plannedRoute', () {
    const Ride r = Ride(
      id: 'r1',
      name: 'Trip',
      code: 'ABC123',
      createdBy: 'u1',
      status: 'active',
      memberCount: 1,
      origin: RideDestination(lat: 1, lng: 1, label: 'A'),
      waypoints: <RideDestination>[RideDestination(lat: 2, lng: 2, label: 'B')],
      destination: RideDestination(lat: 3, lng: 3, label: 'C'),
      plannedRoute: <LatLng>[LatLng(1, 1), LatLng(3, 3)],
      plannedDistanceMeters: 1234,
      plannedDurationSeconds: 600,
    );
    final Map<String, dynamic> m = r.toMap();
    expect((m['origin'] as Map)['label'], 'A');
    expect((m['waypoints'] as List).length, 1);
    expect((m['plannedRoute'] as List).length, 2);
    expect((m['plannedRoute'] as List).first, <String, dynamic>{'lat': 1.0, 'lng': 1.0});
    expect(m['plannedDistanceMeters'], 1234);
  });
```

Add the imports at the top of `test/models_test.dart`:

```dart
import 'package:latlong2/latlong.dart';
```
(`RideDestination` comes from the existing `ride.dart` import.)

- [ ] **Step 2: Run it, expect failure**

Run: `flutter test test/models_test.dart`
Expected: FAIL — named params `origin`/`waypoints`/`plannedRoute`/
`orderedStops` not defined.

- [ ] **Step 3: Extend the `Ride` class**

Edit `lib/models/ride.dart`. Add the `latlong2` import at the top:

```dart
import 'package:latlong2/latlong.dart';
```

Add the new fields to the class (after `destination`):

```dart
  final RideDestination? origin;
  final List<RideDestination> waypoints;
  final List<LatLng>? plannedRoute;
  final double? plannedDistanceMeters;
  final double? plannedDurationSeconds;
```

Add them to the constructor (after `this.destination,`):

```dart
    this.origin,
    this.waypoints = const <RideDestination>[],
    this.plannedRoute,
    this.plannedDistanceMeters,
    this.plannedDurationSeconds,
```

Add the `orderedStops` getter (near `destinationLabel`):

```dart
  List<RideDestination> get orderedStops => <RideDestination>[
        if (origin != null) origin!,
        ...waypoints,
        if (destination != null) destination!,
      ];
```

Update `toMap` — add these entries to the returned map (alongside the
existing `destination` entry):

```dart
        'origin': origin?.toMap(),
        'waypoints':
            waypoints.map((RideDestination w) => w.toMap()).toList(),
        'plannedRoute': plannedRoute
            ?.map((LatLng p) =>
                <String, dynamic>{'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'plannedDistanceMeters': plannedDistanceMeters,
        'plannedDurationSeconds': plannedDurationSeconds,
```

Update `fromDoc` — parse the new fields (tolerating absence). Inside the
factory, after the existing `dest`/`ts` locals, add:

```dart
    final dynamic orig = m['origin'];
    final dynamic wps = m['waypoints'];
    final dynamic pr = m['plannedRoute'];
```

and pass to the returned `Ride(...)`:

```dart
      origin:
          orig is Map<String, dynamic> ? RideDestination.fromMap(orig) : null,
      waypoints: wps is List
          ? wps
              .whereType<Map<String, dynamic>>()
              .map(RideDestination.fromMap)
              .toList()
          : const <RideDestination>[],
      plannedRoute: pr is List
          ? pr
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> p) =>
                  LatLng((p['lat'] as num).toDouble(),
                      (p['lng'] as num).toDouble()))
              .toList()
          : null,
      plannedDistanceMeters: (m['plannedDistanceMeters'] as num?)?.toDouble(),
      plannedDurationSeconds: (m['plannedDurationSeconds'] as num?)?.toDouble(),
```

- [ ] **Step 4: Run tests, expect pass**

Run: `flutter test test/models_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + full test**

Run: `flutter analyze` → no new issues. `flutter test` → all pass.

---

### Task 3: `RideService.createRide` persists the new fields

**Files:**
- Modify: `lib/services/ride_service.dart`

**Interfaces:**
- Produces: `createRide` gains optional params `RideDestination? origin`,
  `List<RideDestination> waypoints = const []`, `List<LatLng>? plannedRoute`,
  `double? plannedDistanceMeters`, `double? plannedDurationSeconds`.

- [ ] **Step 1: Add the import + params**

Edit `lib/services/ride_service.dart`. Add at the top:

```dart
import 'package:latlong2/latlong.dart';
```

Change the `createRide` signature from:

```dart
  Future<Ride> createRide({
    required String name,
    RideDestination? destination,
  }) async {
```

to:

```dart
  Future<Ride> createRide({
    required String name,
    RideDestination? destination,
    RideDestination? origin,
    List<RideDestination> waypoints = const <RideDestination>[],
    List<LatLng>? plannedRoute,
    double? plannedDistanceMeters,
    double? plannedDurationSeconds,
  }) async {
```

- [ ] **Step 2: Pass them into the `Ride`**

In the same method, the `Ride ride = Ride(...)` construction currently
passes `destination: destination`. Add the new fields to that
construction:

```dart
    final Ride ride = Ride(
      id: rideRef.id,
      name: name.trim(),
      code: code,
      destination: destination,
      origin: origin,
      waypoints: waypoints,
      plannedRoute: plannedRoute,
      plannedDistanceMeters: plannedDistanceMeters,
      plannedDurationSeconds: plannedDurationSeconds,
      createdBy: uid,
      status: 'active',
      memberCount: 1,
    );
```

`batch.set(rideRef, ride.toMap(isNew: true))` already writes everything
via the updated `toMap`, so no other change here.

- [ ] **Step 3: Analyze + test**

Run: `flutter analyze` → no new issues (the existing `create_ride_controller`
call to `createRide(name:, destination:)` still compiles — new params are
optional). `flutter test` → all pass.

---

### Task 4: Create-ride UI — origin + reorderable waypoints + destination

**Files:**
- Modify: `lib/modules/rides/create_ride_controller.dart`
- Modify: `lib/modules/rides/create_ride_tab.dart`

**Interfaces:**
- Consumes: `RoutingService.routeMulti` (Task 1),
  `RideService.createRide(...)` (Task 3), `GeoService.searchPlaces`
  (existing), `RideDestination` (existing).
- Produces on the controller: a `_StopEditor` helper class; `origin`
  (`_StopEditor`), `waypoints` (`RxList<_StopEditor>`), `destination`
  (`_StopEditor`); `addWaypoint()`, `removeWaypoint(int)`,
  `reorderWaypoints(int oldIndex, int newIndex)`; per-editor
  `onSearchChanged(_StopEditor, String)` and `choose(_StopEditor,
  PlaceResult)`.

- [ ] **Step 1: Rewrite `create_ride_controller.dart`**

Replace the whole file with:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/place_result.dart';
import '../../models/ride.dart';
import '../../models/route_result.dart';
import '../../services/geo_service.dart';
import '../../services/ride_service.dart';
import '../../services/routing_service.dart';
import 'rides_shell_controller.dart';

/// One search-and-pick field (origin, a waypoint, or destination).
class StopEditor {
  final TextEditingController field = TextEditingController();
  final Rxn<PlaceResult> chosen = Rxn<PlaceResult>();
  final RxList<PlaceResult> suggestions = <PlaceResult>[].obs;
  final RxBool searching = false.obs;
  Timer? debounce;

  void dispose() {
    debounce?.cancel();
    field.dispose();
  }
}

class CreateRideController extends GetxController {
  final GeoService _geo = Get.find<GeoService>();
  final RideService _rides = Get.find<RideService>();
  final RoutingService _routing = Get.find<RoutingService>();

  final TextEditingController nameField = TextEditingController();
  final StopEditor origin = StopEditor();
  final StopEditor destination = StopEditor();
  final RxList<StopEditor> waypoints = <StopEditor>[].obs;
  final RxBool creating = false.obs;
  bool _isDisposed = false;

  void addWaypoint() => waypoints.add(StopEditor());

  void removeWaypoint(int i) {
    if (i < 0 || i >= waypoints.length) return;
    waypoints[i].dispose();
    waypoints.removeAt(i);
  }

  void reorderWaypoints(int oldIndex, int newIndex) {
    // ReorderableListView convention: adjust when moving down.
    int n = newIndex;
    if (n > oldIndex) n -= 1;
    final StopEditor e = waypoints.removeAt(oldIndex);
    waypoints.insert(n, e);
  }

  void onSearchChanged(StopEditor e, String q) {
    e.chosen.value = null;
    e.debounce?.cancel();
    if (q.trim().length < 3) {
      e.suggestions.clear();
      return;
    }
    e.debounce = Timer(const Duration(milliseconds: 550), () async {
      e.searching.value = true;
      e.suggestions.value = await _geo.searchPlaces(q);
      e.searching.value = false;
    });
  }

  void choose(StopEditor e, PlaceResult p) {
    e.chosen.value = p;
    e.field.text = p.displayName;
    e.suggestions.clear();
  }

  RideDestination? _dest(StopEditor e) {
    final PlaceResult? p = e.chosen.value;
    if (p == null) return null;
    return RideDestination(lat: p.lat, lng: p.lng, label: p.displayName);
  }

  Future<void> create() async {
    if (nameField.text.trim().isEmpty) {
      UiHelpers.error('Give your ride a name.');
      return;
    }
    creating.value = true;
    try {
      final RideDestination? originD = _dest(origin);
      final List<RideDestination> waypointDs = waypoints
          .map(_dest)
          .whereType<RideDestination>()
          .toList();
      final RideDestination? destD = _dest(destination);

      final List<RideDestination> ordered = <RideDestination>[
        if (originD != null) originD,
        ...waypointDs,
        if (destD != null) destD,
      ];

      List<LatLng>? plannedRoute;
      double? plannedDist;
      double? plannedDur;
      if (ordered.length >= 2) {
        final RouteResult? r = await _routing.routeMulti(
          ordered
              .map((RideDestination s) => LatLng(s.lat, s.lng))
              .toList(),
        );
        if (r != null) {
          plannedRoute = r.points;
          plannedDist = r.distanceMeters;
          plannedDur = r.durationSeconds;
        } else {
          UiHelpers.warning(
              'Ride created, but the route couldn\'t be planned right now.');
        }
      }

      final Ride ride = await _rides.createRide(
        name: nameField.text,
        origin: originD,
        waypoints: waypointDs,
        destination: destD,
        plannedRoute: plannedRoute,
        plannedDistanceMeters: plannedDist,
        plannedDurationSeconds: plannedDur,
      );
      _showCreated(ride);
      if (!_isDisposed) {
        nameField.clear();
        origin.field.clear();
        origin.chosen.value = null;
        origin.suggestions.clear();
        destination.field.clear();
        destination.chosen.value = null;
        destination.suggestions.clear();
        for (final StopEditor e in waypoints) {
          e.dispose();
        }
        waypoints.clear();
        Get.find<RidesShellController>().tabIndex.value = 0;
      }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 44),
            const SizedBox(height: 12),
            const Text('Ride created!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            const Text('Share this code with your crew:'),
            const SizedBox(height: 12),
            SelectableText(
              ride.code,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Share.share(
                'Join my RideTogether ride "${ride.name}" with code: ${ride.code}',
              ),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share code'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Get.back(), child: const Text('Done')),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  void onClose() {
    _isDisposed = true;
    nameField.dispose();
    origin.dispose();
    destination.dispose();
    for (final StopEditor e in waypoints) {
      e.dispose();
    }
    super.onClose();
  }
}
```

- [ ] **Step 2: Rewrite `create_ride_tab.dart`**

Replace the whole file with (a reusable `_stopField` builds each search
field + its suggestion dropdown + chosen chip; waypoints use a
`ReorderableListView`):

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/place_result.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'create_ride_controller.dart';

class CreateRideTab extends StatelessWidget {
  const CreateRideTab({super.key});

  @override
  Widget build(BuildContext context) {
    final CreateRideController c = Get.put(CreateRideController());
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Obx(
      () => LoadingOverlay(
        isLoading: c.creating.value,
        message: 'Creating ride…',
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.add_road_rounded,
                          size: 20, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'New ride details',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: c.nameField,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ride name',
                    hintText: 'Weekend to Lonavala',
                    prefixIcon: Icon(Icons.edit_road_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                _stopField(context, c, c.origin,
                    label: 'Origin (optional)',
                    icon: Icons.trip_origin),
                const SizedBox(height: 12),
                // Waypoints (reorderable).
                Obx(
                  () => ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: c.waypoints.length,
                    onReorder: c.reorderWaypoints,
                    itemBuilder: (BuildContext ctx, int i) {
                      final StopEditor e = c.waypoints[i];
                      return Padding(
                        key: ValueKey<StopEditor>(e),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: <Widget>[
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                            Expanded(
                              child: _stopField(context, c, e,
                                  label: 'Stop ${i + 1}',
                                  icon: Icons.place_outlined),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => c.removeWaypoint(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: c.addWaypoint,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add stop'),
                  ),
                ),
                const SizedBox(height: 12),
                _stopField(context, c, c.destination,
                    label: 'Destination (optional)',
                    icon: Icons.flag_outlined),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Create ride',
                  icon: Icons.add_road_rounded,
                  onPressed: c.create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stopField(
    BuildContext context,
    CreateRideController c,
    StopEditor e, {
    required String label,
    required IconData icon,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: e.field,
            onChanged: (String q) => c.onSearchChanged(e, q),
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Search a place',
              prefixIcon: Icon(icon),
              suffixIcon: e.searching.value
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (e.chosen.value != null
                      ? Icon(Icons.check_circle, color: AppColors.success)
                      : null),
            ),
          ),
          ...e.suggestions.map(
            (PlaceResult p) => Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant
                      .withValues(alpha: isDark ? 0.3 : 0.15),
                ),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.location_on_outlined,
                    size: 18, color: scheme.primary),
                title: Text(
                  p.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                onTap: () => c.choose(e, p),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze + test**

Run: `flutter analyze` → no new issues. `flutter test` → all pass.

- [ ] **Step 4: Manual smoke (create side)**

On-device: Create tab → enter name, search + pick an origin, Add stop ×2
and pick each, pick a destination, drag to reorder a stop → Create.
Confirm the "Ride created" sheet appears. (Map side verified in Task 5.)

---

### Task 5: Live map — planned route line + numbered stop pins

**Files:**
- Modify: `lib/modules/ride_map/ride_map_controller.dart`
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Consumes: `Ride.plannedRoute`, `Ride.orderedStops` (Task 2). The
  controller already streams the `Ride` (via `_rideService.watchRide` in
  `_start`, currently only used to set `destination`).

- [ ] **Step 1: Expose the ride's planned route + stops on the controller**

Edit `lib/modules/ride_map/ride_map_controller.dart`. Add fields near
`destination`:

```dart
  final Rxn<List<LatLng>> plannedRoute = Rxn<List<LatLng>>();
  final RxList<RideDestination> orderedStops = <RideDestination>[].obs;
```

Add the import for `RideDestination` — it comes from
`../../models/ride.dart`, which is ALREADY imported (the controller uses
`Ride`). No new import needed.

In `_start`, the existing `watchRide` listener sets `destination`.
Extend that same listener callback to also populate the new fields:

```dart
    _rideService.watchRide(rideId).listen((Ride? r) {
      final dest = r?.destination;
      destination.value = dest == null ? null : LatLng(dest.lat, dest.lng);
      plannedRoute.value = r?.plannedRoute;
      orderedStops.value = r?.orderedStops ?? <RideDestination>[];
    });
```

- [ ] **Step 2: Draw the planned route under the live routes**

Edit `lib/modules/ride_map/ride_map_view.dart`. In `_routePolylines()`,
at the VERY START of the method (so it renders under member/my routes),
insert the planned-route line before the existing member-route loop:

```dart
  List<Polyline> _routePolylines() {
    final List<Polyline> lines = <Polyline>[];
    final List<LatLng>? planned = controller.plannedRoute.value;
    if (planned != null && planned.length >= 2) {
      lines.add(
        Polyline(
          points: planned,
          color: AppColors.ink.withValues(alpha: 0.35),
          strokeWidth: 6,
        ),
      );
    }
    controller.memberRoutes.forEach((String uid, RouteResult route) {
```

(the rest of the method — member loop + my gradient route — stays exactly
as-is below this).

- [ ] **Step 3: Numbered stop pins instead of the single destination flag**

Still in `ride_map_view.dart`, in `_markers(BuildContext context)`,
replace the existing destination-flag block:

```dart
    final LatLng? dest = controller.destination.value;
    if (dest != null) {
      markers.add(
        Marker(
          point: dest,
          width: 44,
          height: 44,
          child:
              const Icon(Icons.flag_rounded, color: AppColors.sos, size: 36),
        ),
      );
    }
```

with a loop over `orderedStops` (origin = start pin, middle = numbered,
last = flag). Insert BEFORE the existing `markers.addAll(_routeArrows());`
line, and DELETE the old destination-flag block above:

```dart
    final List<RideDestination> stops = controller.orderedStops;
    for (int i = 0; i < stops.length; i++) {
      final RideDestination s = stops[i];
      final bool isFirst = i == 0;
      final bool isLast = i == stops.length - 1;
      final Widget pin;
      if (isFirst && stops.length > 1) {
        pin = const Icon(Icons.trip_origin,
            color: AppColors.success, size: 30);
      } else if (isLast) {
        pin = const Icon(Icons.flag_rounded, color: AppColors.sos, size: 36);
      } else {
        pin = Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.seed,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$i', // waypoints are 1..n-1 (origin is index 0)
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        );
      }
      markers.add(
        Marker(
          point: LatLng(s.lat, s.lng),
          width: 44,
          height: 44,
          child: Transform.rotate(angle: counterRotation, child: pin),
        ),
      );
    }
```

Note: `orderedStops` is `List<RideDestination>`, and `RideDestination` is
from `../../models/ride.dart`. Confirm `ride_map_view.dart` imports it; if
not, add `import '../../models/ride.dart';`. `counterRotation` is already
computed at the top of `_markers` (from the navigation-rotation feature).

- [ ] **Step 4: Analyze + test**

Run: `flutter analyze` → no new issues. `flutter test` → all pass.

- [ ] **Step 5: Manual on-device verification (full feature)**

With a device (2 for the member bits):
1. Create a ride: name + origin (search Indore) + 2 stops (Manawar,
   Kukshi) + destination (Dahi); reorder a stop by dragging → Create.
2. Open the ride's live map → a planned route line runs
   origin→stops→destination; pins show origin (start), numbered 1/2, and
   destination (flag).
3. Members' own live routes + follow/rotation still work.
4. Create a ride with NO stops → still creates; map shows no planned
   route/pins, no errors.
5. Open an OLD pre-existing ride (created before this feature) → loads
   fine, no planned route/pins, no crash.

Report which checks pass; don't mark complete until all do.
