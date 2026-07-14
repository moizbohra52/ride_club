# Live Map — Google-Maps-Style Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the live map feel like Google Maps: smooth animated camera,
on-screen zoom + fit-all controls, photo-based member pins with tap-to-
detail, dark-mode tiles, and a polished route (gradient line + direction
arrows).

**Architecture:** Swap `RideMapController`'s raw `MapController` for an
`AnimatedMapController` (from `flutter_map_animations`, pinned to the
flutter_map-7-compatible version), routing all camera moves through it.
Then layer on view-only enhancements (controls, pins, tiles, route) task
by task.

**Tech Stack:** Flutter, GetX, `flutter_map: ^7.0.2`,
`flutter_map_animations: 0.8.0` (the version whose constraint is
`flutter_map >=7.0.0 <8.0.0` — verified on pub.dev; 0.9.0+ require
flutter_map 8.x and MUST NOT be used here), `latlong2: 0.9.1`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-map-google-maps-enhancements-design.md`.
- **Pin `flutter_map_animations: 0.8.0` exactly** (not `^0.8.0`, to avoid
  resolving to a flutter_map-8 version). Do NOT upgrade `flutter_map`
  off 7.x.
- Verified `flutter_map_animations 0.8.0` API:
  - `AnimatedMapController({required TickerProvider vsync, MapController? mapController, Duration duration = const Duration(milliseconds: 500), Curve curve = Curves.fastOutSlowIn, bool cancelPreviousAnimations = false})`
  - `Future<void> animateTo({LatLng? dest, double? zoom, Offset offset = Offset.zero, double? rotation, Curve? curve, String? customId, Duration? duration, bool? cancelPreviousAnimations})`
  - `Future<void> animatedFitCamera({required CameraFit cameraFit, Curve? curve, String? customId, double? rotation, Duration? duration, bool? cancelPreviousAnimations})`
  - `MapController get mapController` (the underlying raw controller).
- Verified flutter_map 7.0.2 API: `CameraFit.coordinates({required List<LatLng> coordinates, EdgeInsets padding, double? maxZoom, double minZoom, bool forceIntegerZoomLevel})`; `MapCamera.rotation` (degrees); `MapController.camera`.
- Do not modify `RideLocationService`, `LocationService`,
  `RoutingService`, `ChatService`, `SosService`, `RideService`, or any
  RTDB/Firestore schema.
- Preserve all existing behavior: follow mode, navigation rotation,
  drag-cancels-follow, marker counter-rotation, SOS, chat badge,
  members/detail sheets.
- After every task: `flutter analyze` (no new issues) and `flutter test`
  (all existing tests pass). This project is NOT a git repo — skip commit
  steps.

---

## File Structure

- Modify: `pubspec.yaml` — add `flutter_map_animations: 0.8.0`.
- Modify: `lib/modules/ride_map/ride_map_controller.dart` — animated
  controller + camera calls, fit-all + zoom helpers.
- Modify: `lib/modules/ride_map/ride_map_view.dart` — pass underlying
  controller to FlutterMap, controls stack, photo pins, dark tiles,
  route polish.
- Modify: `lib/core/constants/app_constants.dart` — dark tile URL.

---

### Task 1: Add dependency + swap to AnimatedMapController (behavior identical, now animated)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/modules/ride_map/ride_map_controller.dart`
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Produces: `RideMapController.animatedMapController` (`AnimatedMapController`);
  `RideMapController.mapController` getter now returns the underlying
  `MapController` (`animatedMapController.mapController`) so `RideMapView`
  and the marker counter-rotation keep working unchanged.
- Consumes: `flutter_map_animations` package.

- [ ] **Step 1: Add the dependency**

Edit `pubspec.yaml`, under `dependencies:`, directly after the
`flutter_map: ^7.0.2` line, add:

```yaml
  flutter_map_animations: 0.8.0
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: resolves successfully with `flutter_map_animations 0.8.0` and
`flutter_map` staying on 7.x. If pub reports a version conflict forcing
flutter_map to 8.x, STOP — do not upgrade flutter_map; report the
conflict.

- [ ] **Step 3: Convert `RideMapController` to use AnimatedMapController**

Edit `lib/modules/ride_map/ride_map_controller.dart`. Add the import
after the existing `flutter_map` import:

```dart
import 'package:flutter_map_animations/flutter_map_animations.dart';
```

Change the class declaration to mix in a ticker provider (GetX supplies
`GetSingleTickerProviderStateMixin`):

```dart
class RideMapController extends GetxController
    with GetSingleTickerProviderStateMixin {
```

Replace the field:

```dart
  final MapController mapController = MapController();
```

with an animated controller created in `onInit` (it needs `this` as
vsync, so it can't be a field initializer) plus a passthrough getter:

```dart
  late final AnimatedMapController animatedMapController;

  /// The underlying raw MapController — passed to FlutterMap and used for
  /// camera reads (e.g. rotation for marker counter-rotation).
  MapController get mapController => animatedMapController.mapController;
```

In `onInit`, construct it as the FIRST line (before `_start()`):

```dart
  @override
  void onInit() {
    super.onInit();
    animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      cancelPreviousAnimations: true,
    );
    _start();
  }
```

(`cancelPreviousAnimations: true` makes each new follow-tick retarget
cleanly instead of stacking.)

- [ ] **Step 4: Route the two camera calls through animateTo**

In `_startFollowing`, replace:

```dart
    mapController.moveAndRotate(
      _cameraCenterBehind(pos, heading),
      16,
      -heading,
    );
```

with:

```dart
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: 16,
      rotation: -heading,
    );
```

In `_followIfActive`, replace:

```dart
    mapController.moveAndRotate(
      _cameraCenterBehind(pos, heading),
      mapController.camera.zoom,
      -heading,
    );
```

with:

```dart
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: mapController.camera.zoom,
      rotation: -heading,
    );
```

- [ ] **Step 5: Dispose the animated controller**

`AnimatedMapController` owns an `AnimationController`; dispose it. In
`onClose`, add its disposal before the existing body:

```dart
  @override
  void onClose() {
    animatedMapController.dispose();
    _rideLoc.stopSharing(rideId);
    super.onClose();
  }
```

- [ ] **Step 6: View — no code change needed, verify passthrough**

`RideMapView` uses `controller.mapController` in two places
(`FlutterMap(mapController: controller.mapController)` and
`controller.mapController.camera.rotation` in `_markers()`). Because the
`mapController` getter now returns the underlying raw `MapController`,
BOTH keep compiling and working unchanged. Confirm by reading those two
lines — do not edit them.

- [ ] **Step 7: Analyze + test**

Run: `flutter analyze`
Expected: no new issues.
Run: `flutter test`
Expected: all existing tests pass.

- [ ] **Step 8: Manual smoke check (before layering more)**

Because this swaps the camera engine, verify on-device (emulator ok):
open live map, confirm it still centers on you, recenter FAB still
works and now animates smoothly, dragging still cancels follow. If
follow feels jerky, the follow `animateTo` duration can be shortened
later — note it, don't block.

---

### Task 2: Zoom + fit-all control stack

**Files:**
- Modify: `lib/modules/ride_map/ride_map_controller.dart`
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Produces: `RideMapController.zoomIn()`, `zoomOut()`, `fitAll()`.
- Consumes: `animatedMapController` (Task 1), `CameraFit.coordinates`.

- [ ] **Step 1: Add zoom + fit helpers to the controller**

Add the import for `CameraFit` — it's already exported by
`package:flutter_map/flutter_map.dart` (already imported). Add these
methods near `recenter()`:

```dart
  void zoomIn() {
    animatedMapController.animateTo(zoom: mapController.camera.zoom + 1);
  }

  void zoomOut() {
    animatedMapController.animateTo(zoom: mapController.camera.zoom - 1);
  }

  /// One-shot overview: frame all members + me + destination. Stops follow
  /// (like a manual gesture) so the auto-follow loop won't yank the camera.
  void fitAll() {
    isFollowing.value = false;
    final List<LatLng> pts = <LatLng>[
      for (final MemberLocation m in members) LatLng(m.lat, m.lng),
    ];
    final LatLng? me = myLatLng.value;
    if (me != null) pts.add(me);
    final LatLng? dest = destination.value;
    if (dest != null) pts.add(dest);

    if (pts.isEmpty) return;
    if (pts.length == 1) {
      animatedMapController.animateTo(dest: pts.first, zoom: 16);
      return;
    }
    animatedMapController.animatedFitCamera(
      cameraFit: CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(64),
        maxZoom: 16,
      ),
    );
  }
```

- [ ] **Step 2: Add the control stack to the view**

Edit `lib/modules/ride_map/ride_map_view.dart`. The existing recenter FAB
is `Positioned(right: 16, bottom: 96, ...)`. Add a new `Positioned`
control column ABOVE it (higher on screen) for zoom + fit. Insert this
`Positioned` widget into the `SafeArea > Stack` children, right before the
existing recenter `Positioned(right: 16, bottom: 96, ...)`:

```dart
                  Positioned(
                    right: 16,
                    bottom: 168,
                    child: Column(
                      children: <Widget>[
                        FloatingActionButton.small(
                          heroTag: 'zoomIn',
                          onPressed: controller.zoomIn,
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoomOut',
                          onPressed: controller.zoomOut,
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'fitAll',
                          onPressed: controller.fitAll,
                          child: const Icon(Icons.fit_screen_rounded),
                        ),
                      ],
                    ),
                  ),
```

(Each FAB needs a unique `heroTag` — flutter_map screens already follow
this pattern with 'recenter'/'sos'. `bottom: 168` sits the stack above
the recenter FAB at `bottom: 96`.)

- [ ] **Step 3: Analyze + test**

Run: `flutter analyze` → no new issues.
Run: `flutter test` → all pass.

---

### Task 3: Photo-based member pins + tap-to-detail

**Files:**
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Consumes: `controller.rideMemberFor(uid)` (existing), `showMemberDetail`
  (existing, already imported in this file), `CachedNetworkImageProvider`.

- [ ] **Step 1: Add the cached-image import**

At the top of `lib/modules/ride_map/ride_map_view.dart`, add:

```dart
import 'package:cached_network_image/cached_network_image.dart';
```

- [ ] **Step 2: Rewrite `_MemberPin` to a photo pin**

Replace the entire existing `_MemberPin` class (the
`class _MemberPin extends StatelessWidget { ... }` block, NOT
`_PinPainter`) with:

```dart
/// A Google-Maps-style rider pin: a circular profile photo (or colored
/// initial) ringed in the member's color, with a heading arrow and a tiny
/// speed label. Scales in when first shown.
class _MemberPin extends StatelessWidget {
  final Color color;
  final double heading;
  final double speedKmh;
  final bool isMe;
  final String? photoUrl;
  final String name;
  const _MemberPin({
    required this.color,
    required this.heading,
    required this.speedKmh,
    required this.isMe,
    required this.photoUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double scale, Widget? child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Heading arrow behind the avatar, rotated to the heading.
                Transform.rotate(
                  angle: heading * math.pi / 180,
                  child: CustomPaint(
                    size: const Size(52, 52),
                    painter: _ArrowPainter(color: color),
                  ),
                ),
                // Circular avatar with a colored ring.
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isMe ? AppColors.seed : color,
                      width: 3,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: color.withValues(alpha: 0.15)),
                            errorWidget: (_, __, ___) =>
                                _initialAvatar(),
                          )
                        : _initialAvatar(),
                  ),
                ),
              ],
            ),
          ),
          if (speedKmh >= 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${speedKmh.toStringAsFixed(0)} km/h',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialAvatar() => Container(
        color: color.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      );
}

/// Small direction triangle drawn at the top of the pin (points "up" at
/// heading 0; the parent Transform.rotate turns it to the real heading).
class _ArrowPainter extends CustomPainter {
  final Color color;
  _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final Paint p = Paint()..color = color;
    final Path arrow = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx - 7, 12)
      ..lineTo(cx + 7, 12)
      ..close();
    canvas.drawPath(arrow, p);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => old.color != color;
}
```

Note: the OLD `_PinPainter` class is now unused after this change. Delete
the entire `class _PinPainter extends CustomPainter { ... }` block at the
bottom of the file (it was only referenced by the old `_MemberPin`).

- [ ] **Step 3: Pass photo/name + add tap in `_markers()`**

In `_markers()`, the member loop currently builds
`child: Transform.rotate(angle: counterRotation, child: _MemberPin(...))`.
Replace the member-marker `child:` with a looked-up profile, a tap
handler, and the new `_MemberPin` params:

```dart
    for (final MemberLocation m in controller.members) {
      if (m.uid == controller.uid) continue; // Don't duplicate the "me" marker
      final RideMember? profile = controller.rideMemberFor(m.uid);
      final RouteResult? route = controller.routeFor(m.uid);
      final RideMember resolved = profile ??
          RideMember(
            uid: m.uid,
            name: 'Rider',
            colorValue: AppColors.memberColorForKey(m.uid).toARGB32(),
            role: 'rider',
          );
      markers.add(
        Marker(
          key: ValueKey<String>(m.uid),
          point: LatLng(m.lat, m.lng),
          width: 80,
          height: 80,
          child: Transform.rotate(
            angle: counterRotation,
            child: GestureDetector(
              onTap: () => showMemberDetail(
                context,
                member: resolved,
                rideId: controller.rideId,
                live: m,
                route: route,
              ),
              child: _MemberPin(
                color: AppColors.memberColorForKey(m.uid),
                heading: m.heading,
                speedKmh: m.speedKmh,
                isMe: false,
                photoUrl: profile?.photoUrl,
                name: resolved.name,
              ),
            ),
          ),
        ),
      );
    }
```

This needs `RideMember` and `RouteResult` — `RideMember` is already
imported in this file (added in the member-detail feature); `RouteResult`
is already imported too. Confirm both imports exist at the top; if
`RideMember` is missing, add
`import '../../models/ride_member.dart';`.

- [ ] **Step 4: Make the my-location marker a photo pin too**

In `_markers()`, replace the existing my-location marker child (currently
`Transform.rotate(angle: counterRotation, child: Icon(Icons.my_location_rounded, ...))`)
with a `_MemberPin` for myself:

```dart
    final LatLng? me = controller.myLatLng.value;
    if (me != null) {
      final RideMember? myProfile =
          controller.uid == null ? null : controller.rideMemberFor(controller.uid!);
      markers.add(
        Marker(
          key: const ValueKey('my_location'),
          point: me,
          width: 80,
          height: 80,
          child: Transform.rotate(
            angle: counterRotation,
            child: _MemberPin(
              color: AppColors.seed,
              heading: controller.myHeading.value,
              speedKmh: 0,
              isMe: true,
              photoUrl: myProfile?.photoUrl,
              name: myProfile?.name ?? 'Me',
            ),
          ),
        ),
      );
    }
```

(Speed label hidden for self via `speedKmh: 0` since `>= 1` gates it;
`myHeading` is already a controller field from the navigation-rotation
feature.)

- [ ] **Step 5: Analyze + test**

Run: `flutter analyze` → no new issues (watch for: unused `_PinPainter`
if the delete was missed; missing imports).
Run: `flutter test` → all pass.

---

### Task 4: Dark-mode map tiles

**Files:**
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Produces: `AppConstants.osmTileUrlDark`.

- [ ] **Step 1: Add the dark tile URL constant**

Edit `lib/core/constants/app_constants.dart`. After the existing
`osmTileUrl` constant, add:

```dart
  /// CARTO dark-matter raster tiles (OSM-based) for dark theme. Requires
  /// CARTO + OSM attribution (shown in the map's attribution widget).
  static const String osmTileUrlDark =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
```

- [ ] **Step 2: Pick the tile URL by theme + update attribution**

Edit `lib/modules/ride_map/ride_map_view.dart`. In `build`, the `body`'s
`Obx` already computes `center`; just below that line (before
`return Stack(`), add:

```dart
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final String tileUrl =
            isDark ? AppConstants.osmTileUrlDark : AppConstants.osmTileUrl;
```

Change the `TileLayer`:

```dart
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: AppConstants.userAgentPackageName,
                ),
```

Update the `RichAttributionWidget` to add CARTO credit when dark:

```dart
                RichAttributionWidget(
                  attributions: <SourceAttribution>[
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright'),
                      ),
                    ),
                    if (isDark)
                      TextSourceAttribution(
                        'CARTO',
                        onTap: () =>
                            launchUrl(Uri.parse('https://carto.com/attributions')),
                      ),
                  ],
                ),
```

- [ ] **Step 3: Analyze + test**

Run: `flutter analyze` → no new issues.
Run: `flutter test` → all pass.

---

### Task 5: Route polish (gradient line + direction arrows)

**Files:**
- Modify: `lib/modules/ride_map/ride_map_view.dart`

**Interfaces:**
- Consumes: `controller.myRoute` (existing `Rxn<RouteResult>`),
  `controller.memberRoutes` (existing).

- [ ] **Step 1: Thicker gradient (glow) for my route**

In `_routePolylines()`, replace the my-route block:

```dart
    final RouteResult? myR = controller.myRoute.value;
    if (myR != null) {
      lines.add(
        Polyline(points: myR.points, color: AppColors.seed, strokeWidth: 5),
      );
    }
```

with a two-layer draw (wide translucent glow under a solid core):

```dart
    final RouteResult? myR = controller.myRoute.value;
    if (myR != null) {
      lines.add(
        Polyline(
          points: myR.points,
          color: AppColors.seed.withValues(alpha: 0.25),
          strokeWidth: 12,
        ),
      );
      lines.add(
        Polyline(points: myR.points, color: AppColors.seed, strokeWidth: 6),
      );
    }
```

(Order matters: the glow is added first so it renders under the core.
Member routes above this block are unchanged.)

- [ ] **Step 2: Add direction-arrow markers along my route**

Add a helper method to `RideMapView` that samples the route and builds
small arrow markers oriented along each sampled segment, then call it
from `_markers()`.

Add this method (near `_markers()`):

```dart
  List<Marker> _routeArrows() {
    final RouteResult? myR = controller.myRoute.value;
    if (myR == null || myR.points.length < 2) return <Marker>[];
    final double counterRotation =
        -controller.mapController.camera.rotation * (math.pi / 180);
    final List<Marker> arrows = <Marker>[];
    const int step = 10; // ~1 arrow per 10 route points
    for (int i = step; i < myR.points.length; i += step) {
      final LatLng a = myR.points[i - 1];
      final LatLng b = myR.points[i];
      final double bearing = _bearing(a, b);
      arrows.add(
        Marker(
          point: b,
          width: 24,
          height: 24,
          child: Transform.rotate(
            angle: counterRotation + (bearing * math.pi / 180),
            child: Icon(
              Icons.navigation_rounded,
              color: AppColors.seed,
              size: 18,
            ),
          ),
        ),
      );
    }
    return arrows;
  }

  double _bearing(LatLng from, LatLng to) {
    final double lat1 = from.latitude * math.pi / 180;
    final double lat2 = to.latitude * math.pi / 180;
    final double dLon = (to.longitude - from.longitude) * math.pi / 180;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final double deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }
```

`Icons.navigation_rounded` points up (north / 0°) by default, so rotating
it by the segment bearing orients it along the route; adding
`counterRotation` keeps it correct when the map itself is rotated.

- [ ] **Step 3: Append the arrows in `_markers()`**

In `_markers()`, just before the final `return markers;`, add:

```dart
    markers.addAll(_routeArrows());
```

- [ ] **Step 4: Analyze + test**

Run: `flutter analyze` → no new issues.
Run: `flutter test` → all pass.

- [ ] **Step 5: Final manual on-device verification**

With 2 devices in an active ride with a destination set:
1. Camera moves (recenter, member-follow, zoom buttons, fit-all) are all
   smoothly animated.
2. Zoom +/- and fit-all buttons work; fit-all frames everyone + dest.
3. Member pins show profile photos (colored-initial fallback when no
   photo), stay upright, and open the detail sheet on tap.
4. My own pin shows my photo with the seed-color ring.
5. Dark theme → dark map tiles (with CARTO attribution visible); light
   theme → normal tiles.
6. My route renders as a thick gradient line with direction arrows
   pointing toward the destination; arrows stay oriented when the map
   rotates.
7. Everything from before still works: follow, navigation rotation,
   drag-cancels-follow, SOS, chat badge.

Report which checks pass; don't mark complete until all do.
