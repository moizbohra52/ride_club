# Phase 4 — OSRM Routing (polyline, distance, ETA, auto re-route) — Design Spec

**Date:** 2026-07-11
**Project:** `ride_club` (RideTogether)
**Builds on:** Phase 3 (`ride_map` module, `LocationService`, `RideLocationService`, `MemberLocation`).

---

## Locked decisions (from brainstorming)

| Fork | Decision |
|------|----------|
| Route target + profile | Every member → the ride **destination**, **driving** profile. |
| Off-route re-route | **Auto** — if my position is >50m from my route polyline, silently recalc + show "Re-routing…" banner. |
| Distance + ETA | My distance/ETA in a **top info card**; every member's distance/ETA in the **members-sheet**. |
| Recalc frequency | **Debounced**: recalc a member's route only when they move ≥100m or go off-route. All OSRM requests serialized through a **global queue** ≥1.2s apart (OSRM public API fair-use). |
| No destination | If the ride has no destination, map shows markers only + hint "Set a destination to see routes." |

## Service (new)

**`RoutingService`** (GetxService):
- `Future<RouteResult?> route(LatLng from, LatLng to)` — calls
  `GET {osrmBaseUrl}/route/v1/driving/{fromLng},{fromLat};{toLng},{toLat}?overview=full&geometries=polyline&alternatives=false&steps=false`,
  decodes the `routes[0].geometry` (encoded polyline), returns `RouteResult`. Returns null on no-route.
- **Global request queue:** all `route()` calls run through one serial queue that waits ≥1.2s between HTTP requests, so bursts (my route + N members) never exceed OSRM's ~1 req/sec fair-use. Sends `User-Agent: AppConstants.httpUserAgent`.
- Typed errors: 429 → transient (queue retries once after backoff); timeout / no-internet → null + logged.
- **Polyline decoder** — the standard Google-encoded-polyline algorithm as a pure function `decodePolyline(String) -> List<List<double>>`, unit-tested.

## Model

`RouteResult{ List<LatLng> points, double distanceMeters, double durationSeconds }`:
- `double get distanceKm => distanceMeters / 1000`
- `String get distanceText` — "42.3 km" (or "850 m" under 1 km)
- `String get etaText` — "55 min" or "1 h 5 min" from durationSeconds

## Map integration (extends `modules/ride_map`)

`RideMapController` additions:
- `Rxn<RouteResult> myRoute`, `RxMap<String, RouteResult> memberRoutes`, `RxBool rerouting`.
- `LatLng? _destination` (from the ride doc; fetched once via `RideService.watchRide`/one-shot in binding — pass rideId already present).
- `_lastRoutedFrom` per member (LatLng) to enforce the ≥100m debounce.
- Reacts to my position stream + `members` stream:
  - My position: if moved ≥100m since `_lastRoutedFrom['me']` OR off-route(>50m from `myRoute.points`) → enqueue `route(me → dest)`; set `rerouting` while pending.
  - Each member: if moved ≥100m since their last routed point → enqueue `route(member → dest)` → `memberRoutes[uid]`.
- `distanceToPolyline(LatLng, List<LatLng>)` helper for off-route detection (min point distance via `latlong2 Distance`).

`RideMapView` additions:
- `PolylineLayer`: my route bold (`AppColors.seed`, width 5), member routes faint (their color, width 3, low opacity). Drawn **below** MarkerLayer.
- **Destination flag marker** at `_destination`.
- **Top info card** (over map): "You → destination · {distanceText} · {etaText}" or "Set a destination…" when none; a small "Re-routing…" chip when `rerouting`.
- Members-sheet rows: append "· {distanceText} · {etaText}" when that member's route is known.

## Data flow

```
map open → fetch destination
  ├─ no destination → hint card, no routes
  └─ destination set:
       my position tick ──(moved≥100m OR off-route>50m)──► enqueue route(me→dest) ─► myRoute ─► polyline+card
       members stream ──(member moved≥100m)──────────────► enqueue route(m→dest) ─► memberRoutes[uid] ─► faint line + sheet ETA
  all route() calls ─► global serial queue (≥1.2s spacing) ─► OSRM
```

## Error handling
- OSRM 429 → queue backs off and retries once; persistent failure → keep last polyline, log.
- No route / timeout / no-internet → null, existing polyline stays, card shows last known or "—".
- Ride has no destination → hint, skip all routing.
- Empty member routes → sheet shows location only (no ETA).

## Testing
- Unit: `decodePolyline` against a known OSRM/Google sample; `RouteResult.distanceText`/`etaText` formatting; `RoutingService` HTTP parse via MockClient.
- On-device: open map with a destination-set ride → my polyline + card ETA; move mock location → polyline/card update, off-route triggers re-route banner.

## Out of scope (later phases)
Turn-by-turn steps/voice. Chat (5), SOS/FCM (6), history + background hardening + release (7).

## Quality rules (carried forward)
Clean units; compiles/runs; typed friendly errors; OSRM fair-use respected (global throttle); no Google Maps; `flutter analyze` clean; tests pass; verify on emulator.
