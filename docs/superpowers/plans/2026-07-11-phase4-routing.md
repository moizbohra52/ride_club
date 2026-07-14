# Phase 4 — OSRM Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Draw each member's driving route to the ride destination on the map (polyline), show distance + ETA (my route in a top card, all members in the sheet), and silently re-route when I go off-route — all while respecting OSRM's public-API fair-use via a global request queue.

**Architecture:** A `RoutingService` (GetxService) calls OSRM through a serial ≥1.2s-spaced queue and decodes polylines into `RouteResult`. `RideMapController` (Phase 3) gains route state + debounced recalc (≥100m move / >50m off-route). `RideMapView` adds polyline layers, a destination flag, a top info card, and ETA in the members sheet.

**Tech Stack:** http, latlong2, flutter_map, geolocator, GetX. Existing Phase 3 map module.

## Global Constraints

- No Google Maps. OSRM base `AppConstants.osrmBaseUrl`; driving profile; `overview=full&geometries=polyline`.
- Send `User-Agent: AppConstants.httpUserAgent`. All OSRM requests serialized ≥1.2s apart (one global queue).
- Recalc a route only when the origin moved ≥100m, or (for me) off-route >50m.
- `latlong2` exports `Path` — in any file that also uses `dart:ui` `Path`, import latlong2 `hide Path` (already done in ride_map_view).
- Typed friendly errors; keep last polyline on failure; `flutter analyze` clean; tests pass.

---

### Task 1: RouteResult model + polyline decoder

**Files:** Create `lib/models/route_result.dart`, `lib/core/utils/polyline_codec.dart`; Test `test/routing_test.dart`

**Interfaces:**
- Produces:
  - `decodePolyline(String encoded) -> List<List<double>>` (each `[lat, lng]`) — standard Google polyline algorithm, precision 1e5.
  - `RouteResult{ List<LatLng> points, double distanceMeters, double durationSeconds }`; `distanceKm`, `distanceText`, `etaText`.

- [ ] **Step 1: Failing test**

```dart
// test/routing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_club/core/utils/polyline_codec.dart';
import 'package:ride_club/models/route_result.dart';

void main() {
  test('decodePolyline decodes the canonical Google sample', () {
    // "_p~iF~ps|U_ulLnnqC_mqNvxq`@" → 3 known points.
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0][0], closeTo(38.5, 0.01));
    expect(pts[0][1], closeTo(-120.2, 0.01));
    expect(pts[2][0], closeTo(43.252, 0.01));
    expect(pts[2][1], closeTo(-126.453, 0.01));
  });

  test('RouteResult formatting', () {
    final r = RouteResult(points: const [LatLng(0, 0)],
        distanceMeters: 42300, durationSeconds: 3300);
    expect(r.distanceText, '42.3 km');
    expect(r.etaText, '55 min');
    final short = RouteResult(points: const [LatLng(0, 0)],
        distanceMeters: 850, durationSeconds: 3900);
    expect(short.distanceText, '850 m');
    expect(short.etaText, '1 h 5 min');
  });
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```dart
// lib/core/utils/polyline_codec.dart
/// Decodes a Google/OSRM encoded polyline (precision 1e5) into [lat,lng] pairs.
List<List<double>> decodePolyline(String encoded) {
  final List<List<double>> points = <List<double>>[];
  int index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    points.add(<double>[lat / 1e5, lng / 1e5]);
  }
  return points;
}
```

```dart
// lib/models/route_result.dart
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;

  String get distanceText => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${distanceKm.toStringAsFixed(1)} km';

  String get etaText {
    final int mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final int h = mins ~/ 60;
    final int m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: analyze clean; commit** `feat(phase4): route model + polyline decoder`.

---

### Task 2: RoutingService — OSRM + global throttle queue

**Files:** Create `lib/services/routing_service.dart`; Test add to `test/routing_test.dart`

**Interfaces:**
- Consumes: `decodePolyline` (T1), `RouteResult`, `AppConstants`, http, latlong2.
- Produces: `RoutingService extends GetxService`:
  - `Future<RouteResult?> route(LatLng from, LatLng to, {http.Client? client})` — enqueued; parses OSRM json.

- [ ] **Step 1: Failing test (MockClient, bypass queue spacing by direct call)**

```dart
// add to test/routing_test.dart
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ride_club/services/routing_service.dart';

  test('RoutingService parses OSRM response', () async {
    final mock = MockClient((req) async {
      expect(req.headers['User-Agent'], isNotEmpty);
      return http.Response(
        '{"code":"Ok","routes":[{"distance":42300.0,"duration":3300.0,'
        '"geometry":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"}]}', 200);
    });
    final svc = RoutingService();
    final r = await svc.route(const LatLng(38.5, -120.2),
        const LatLng(43.2, -126.4), client: mock);
    expect(r, isNotNull);
    expect(r!.distanceMeters, 42300.0);
    expect(r.points.length, 3);
  });
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**

```dart
// lib/services/routing_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart' hide Response;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../core/utils/polyline_codec.dart';
import '../models/route_result.dart';

/// OSRM driving routes, serialized through one global queue that spaces HTTP
/// requests ≥1.2s apart to respect the public API's fair-use policy.
class RoutingService extends GetxService {
  static const Duration _minSpacing = Duration(milliseconds: 1200);
  Future<void> _chain = Future<void>.value();
  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<RouteResult?> route(LatLng from, LatLng to, {http.Client? client}) {
    // Serialize: each call waits for the previous, then honors min spacing.
    final Completer<RouteResult?> out = Completer<RouteResult?>();
    _chain = _chain.then((_) async {
      final int sinceMs = DateTime.now().difference(_lastCall).inMilliseconds;
      final int waitMs = _minSpacing.inMilliseconds - sinceMs;
      if (waitMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
      _lastCall = DateTime.now();
      out.complete(await _fetch(from, to, client));
    });
    return out.future;
  }

  Future<RouteResult?> _fetch(LatLng from, LatLng to, http.Client? client) async {
    final http.Client c = client ?? http.Client();
    try {
      final String coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
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
        Log.e('OSRM ${res.statusCode}');
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final List<dynamic> routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      final Map<String, dynamic> r0 = routes.first as Map<String, dynamic>;
      final List<List<double>> pts = decodePolyline(r0['geometry'] as String);
      return RouteResult(
        points: pts.map((p) => LatLng(p[0], p[1])).toList(),
        distanceMeters: (r0['distance'] as num).toDouble(),
        durationSeconds: (r0['duration'] as num).toDouble(),
      );
    } catch (e, s) {
      Log.e('OSRM route failed', error: e, stack: s);
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}
```

- [ ] **Step 4: Run — PASS** (both routing tests).
- [ ] **Step 5: register in main.dart** — `Get.put<RoutingService>(RoutingService(), permanent: true);` (import it).
- [ ] **Step 6: analyze clean; commit** `feat(phase4): RoutingService with global OSRM throttle`.

---

### Task 3: Map controller — route state, debounced recalc, off-route

**Files:** Modify `lib/modules/ride_map/ride_map_controller.dart`; Modify `lib/modules/ride_map/ride_map_binding.dart` (pass destination); add destination fetch.

**Interfaces:**
- Consumes: `RoutingService` (T2), `RouteResult`, `RideService.watchRide` (Phase 2) to read destination, `latlong2 Distance`.
- Produces on controller: `Rxn<RouteResult> myRoute`, `RxMap<String,RouteResult> memberRoutes`, `RxBool rerouting`, `Rxn<LatLng> destination`, `bool get hasDestination`.

- [ ] **Step 1: Add fields + destination + routing logic to `RideMapController`**

Add imports:
```dart
import '../../models/route_result.dart';
import '../../models/ride.dart';
import '../../services/routing_service.dart';
import '../../services/ride_service.dart';
```
Add fields (near existing Rx fields):
```dart
  final RoutingService _routing = Get.find<RoutingService>();
  final RideService _rideService = Get.find<RideService>();
  final Rxn<RouteResult> myRoute = Rxn<RouteResult>();
  final RxMap<String, RouteResult> memberRoutes = <String, RouteResult>{}.obs;
  final RxBool rerouting = false.obs;
  final Rxn<LatLng> destination = Rxn<LatLng>();
  final Distance _dist = const Distance();
  final Map<String, LatLng> _lastRoutedFrom = <String, LatLng>{};

  bool get hasDestination => destination.value != null;
```
In `_start()`, after permission granted and before/after binding streams, fetch the destination once and wire reactions:
```dart
    // destination (one-shot from the ride doc)
    _rideService.watchRide(rideId).listen((Ride? r) {
      final d = r?.destination;
      destination.value = d == null ? null : LatLng(d.lat, d.lng);
    });

    // my route: recompute on my movement (≥100m or off-route)
    ever<LatLng?>(myLatLng, (LatLng? me) => _maybeRouteMe(me));
    // member routes: recompute when a member moves ≥100m
    ever<List<MemberLocation>>(members, (list) {
      for (final m in list) {
        if (m.uid == uid) continue;
        _maybeRouteMember(m);
      }
    });
```
Add methods:
```dart
  double _meters(LatLng a, LatLng b) => _dist.as(LengthUnit.Meter, a, b);

  double _distanceToRoute(LatLng p, List<LatLng> route) {
    double best = double.infinity;
    for (final LatLng q in route) {
      final double d = _meters(p, q);
      if (d < best) best = d;
    }
    return best;
  }

  Future<void> _maybeRouteMe(LatLng? me) async {
    final LatLng? dest = destination.value;
    if (me == null || dest == null) return;
    final LatLng? last = _lastRoutedFrom['me'];
    final bool moved = last == null || _meters(last, me) >= 100;
    final bool offRoute = myRoute.value != null &&
        _distanceToRoute(me, myRoute.value!.points) > 50;
    if (!moved && !offRoute) return;
    if (offRoute) rerouting.value = true;
    _lastRoutedFrom['me'] = me;
    final RouteResult? r = await _routing.route(me, dest);
    if (r != null) myRoute.value = r;
    rerouting.value = false;
  }

  Future<void> _maybeRouteMember(MemberLocation m) async {
    final LatLng? dest = destination.value;
    if (dest == null) return;
    final LatLng pos = LatLng(m.lat, m.lng);
    final LatLng? last = _lastRoutedFrom[m.uid];
    if (last != null && _meters(last, pos) < 100) return;
    _lastRoutedFrom[m.uid] = pos;
    final RouteResult? r = await _routing.route(pos, dest);
    if (r != null) memberRoutes[m.uid] = r;
  }

  RouteResult? routeFor(String memberUid) =>
      memberUid == uid ? myRoute.value : memberRoutes[memberUid];
```

- [ ] **Step 2: analyze clean; commit** `feat(phase4): map controller routing + off-route recalc`.

---

### Task 4: Map view — polylines, destination flag, info card, sheet ETA

**Files:** Modify `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:** Consumes controller route state (T3), flutter_map `PolylineLayer`, `AppColors`.

- [ ] **Step 1: Add polyline + destination layers** — inside `FlutterMap` children, BEFORE the existing `MarkerLayer`:

```dart
                // Member routes (faint) then my route (bold), under markers.
                Obx(() => PolylineLayer(polylines: _routePolylines())),
```
And add a destination flag into markers (`_markers()`), appended after member pins:
```dart
    final LatLng? dest = controller.destination.value;
    if (dest != null) {
      markers.add(Marker(
        point: dest, width: 40, height: 40,
        child: const Icon(Icons.flag_rounded, color: Color(0xFFE11D48), size: 34),
      ));
    }
```
Add the polyline builder method to the class:
```dart
  List<Polyline> _routePolylines() {
    final List<Polyline> lines = <Polyline>[];
    controller.memberRoutes.forEach((String uid, route) {
      lines.add(Polyline(
        points: route.points,
        color: AppColors.memberColorForKey(uid).withValues(alpha: 0.4),
        strokeWidth: 3,
      ));
    });
    final myR = controller.myRoute.value;
    if (myR != null) {
      lines.add(Polyline(
        points: myR.points, color: AppColors.seed, strokeWidth: 5));
    }
    return lines;
  }
```

- [ ] **Step 2: Add the top info card** — inside the outer `Stack` children (after `FlutterMap`, before the recenter FAB):

```dart
            Positioned(
              top: 12, left: 16, right: 16,
              child: _infoCard(context),
            ),
```
Add the method:
```dart
  Widget _infoCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final String text;
      if (!controller.hasDestination) {
        text = 'Set a destination to see routes';
      } else if (controller.myRoute.value != null) {
        final r = controller.myRoute.value!;
        text = 'To destination · ${r.distanceText} · ${r.etaText}';
      } else {
        text = 'Finding your route…';
      }
      return Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        color: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(Icons.navigation_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
            if (controller.rerouting.value)
              const Padding(padding: EdgeInsets.only(left: 8),
                child: SizedBox(height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ]),
        ),
      );
    });
  }
```

- [ ] **Step 3: Add ETA to the members sheet** — in `_showMembers`, extend the subtitle:

```dart
                subtitle: Builder(builder: (_) {
                  final route = controller.routeFor(m.uid);
                  final eta = route == null
                      ? ''
                      : ' · ${route.distanceText} · ${route.etaText}';
                  return Text(
                    '${m.speedKmh.toStringAsFixed(0)} km/h · ${m.battery}% · '
                    '${m.lastSeenText(now)}$eta');
                }),
```
(Replace the existing `subtitle: Text(...)`.)

- [ ] **Step 4: `flutter analyze` — expect no issues.**
- [ ] **Step 5: commit** `feat(phase4): map polylines + destination flag + ETA card + sheet ETA`.

---

### Task 5: Verify

- [ ] **Step 1:** `flutter analyze` clean, `flutter test` all pass.
- [ ] **Step 2 (on device):** open a ride **with a destination** → map shows my bold polyline to the flag, top card shows distance + ETA.
- [ ] **Step 3:** move mock location off the road (`adb emu geo fix`) → "Re-routing…" chip, new polyline.
- [ ] **Step 4:** members sheet shows each member's km + ETA.
- [ ] **Step 5:** open a ride **without a destination** → "Set a destination to see routes", no polyline. Screenshot both.

---

## Self-Review notes
- **Spec coverage:** decoder+model ✓(T1), OSRM+throttle queue ✓(T2), per-member routes + debounce + off-route ✓(T3), polylines+flag+card+sheet ETA+no-destination hint ✓(T4), verify ✓(T5).
- **Type consistency:** `RouteResult.points/distanceText/etaText`, `RoutingService.route(from,to,{client})`, controller `myRoute/memberRoutes/rerouting/destination/hasDestination/routeFor` used identically across T3/T4.
- **Throttle correctness:** single `_chain` future serializes all `route()` calls; `_minSpacing` gap measured from `_lastCall`. My route + N members all pass through it → ≤~1 req/1.2s regardless of member count.
- **latlong2 `Path`**: ride_map_view already imports `hide Path`; new polyline code uses `Polyline`/`LatLng` only, no `dart:ui` Path — safe.
