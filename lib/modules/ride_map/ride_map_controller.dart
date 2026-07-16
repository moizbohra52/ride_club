import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../core/utils/logger.dart';
import '../../models/member_location.dart';
import '../../models/ride.dart';
import '../../models/ride_member.dart';
import '../../models/route_result.dart';
import '../../models/sos_alert.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_location_service.dart';
import '../../services/ride_service.dart';
import '../../services/routing_service.dart';
import '../../services/sos_service.dart';
import '../sos/sos_ui.dart';

/// Navigation arguments for [Routes.rideMap]. [focusUid], when given, makes
/// the map follow that member on open instead of the current user.
class RideMapArgs {
  final String rideId;
  final String? focusUid;
  const RideMapArgs({required this.rideId, this.focusUid});
}

class RideMapController extends GetxController
    with GetTickerProviderStateMixin {
  final LocationService _loc = Get.find<LocationService>();
  final RideLocationService _rideLoc = Get.find<RideLocationService>();
  final RoutingService _routing = Get.find<RoutingService>();
  final RideService _rideService = Get.find<RideService>();
  final ChatService _chat = Get.find<ChatService>();
  final SosService _sos = Get.find<SosService>();
  final AuthService _auth = Get.find<AuthService>();
  final String rideId;
  final String? initialFocusUid;
  RideMapController(this.rideId, {this.initialFocusUid});

  late final AnimatedMapController animatedMapController;
  bool _isDisposed = false;

  /// The underlying raw MapController — passed to FlutterMap and used for
  /// camera reads (e.g. rotation for marker counter-rotation).
  MapController get mapController => animatedMapController.mapController;

  final RxList<MemberLocation> members = <MemberLocation>[].obs;
  final RxList<RideMember> rideMembers = <RideMember>[].obs;
  final Rxn<LatLng> myLatLng = Rxn<LatLng>();
  final RxDouble myHeading = 0.0.obs;
  final RxBool ready = false.obs;
  final RxnString permissionError = RxnString();
  final RxInt unread = 0.obs;

  // --- Follow mode ---
  /// null = following my own location; a uid = following that member.
  final Rxn<String> followTarget = Rxn<String>();
  final RxBool isFollowing = false.obs;

  /// Google-Maps-style navigation. Before the user taps "Start" the map is a
  /// static preview (no camera follow); once tracking begins the camera locks
  /// onto the target in a tilted-ahead nav view and refreshes on every fix.
  final RxBool isTracking = false.obs;

  /// Whether the recenter button should be shown. Turns true the moment the
  /// user manually moves the camera (pan/zoom/rotate) — like Google Maps —
  /// and back to false once they recenter. Independent of [isTracking].
  final RxBool showRecenter = false.obs;

  // --- Phase 6: SOS ---
  final RxList<SosAlert> activeSos = <SosAlert>[].obs;
  final RxnString mySosId = RxnString();
  final Set<String> _seenSos = <String>{};

  // --- Phase 4: routing ---
  final Rxn<RouteResult> myRoute = Rxn<RouteResult>();
  final RxMap<String, RouteResult> memberRoutes = <String, RouteResult>{}.obs;
  final RxBool rerouting = false.obs;
  final Rxn<LatLng> destination = Rxn<LatLng>();
  final Rxn<List<LatLng>> plannedRoute = Rxn<List<LatLng>>();
  final RxList<RideDestination> orderedStops = <RideDestination>[].obs;
  final Distance _dist = const Distance();
  final Map<String, LatLng> _lastRoutedFrom = <String, LatLng>{};

  /// Current zoom level - updated reactively from map position changes
  final RxDouble zoomLevel = 16.5.obs;

  bool get hasDestination => destination.value != null;

  String? get uid => _auth.uid;

  @override
  void onInit() {
    super.onInit();
    animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      cancelPreviousAnimations: true,
    );
    _start();
  }

  Future<void> _start() async {
    if (initialFocusUid != null) followTarget.value = initialFocusUid;
    final LocationPermissionResult res = await _loc.ensurePermission();
    if (res != LocationPermissionResult.granted) {
      permissionError.value = switch (res) {
        LocationPermissionResult.serviceDisabled =>
          'Location is turned off. Turn it on to share your position.',
        LocationPermissionResult.deniedForever =>
          'Location permission is blocked. Enable it in app settings.',
        _ => 'Location permission is needed to share your position.',
      };
      ready.value = true;
      return;
    }

    final Position? pos = await _loc.currentPosition();
    if (pos != null) myLatLng.value = LatLng(pos.latitude, pos.longitude);

    // Keep my own dot fresh, and share to RTDB, from the battery-aware stream.
    _loc.positionStream().listen((p) {
      myLatLng.value = LatLng(p.lat, p.lng);
      myHeading.value = p.heading;
    });
    _rideLoc.startSharing(rideId, _loc.positionStream());
    members.bindStream(_rideLoc.watchLocations(rideId));
    rideMembers.bindStream(_rideService.watchMembers(rideId));
    unread.bindStream(_chat.unreadCount(rideId));

    // SOS: watch for active alerts, show a full-screen alert for others'.
    activeSos.bindStream(_sos.watchActiveSos(rideId));
    ever<List<SosAlert>>(activeSos, (List<SosAlert> list) {
      for (final SosAlert s in list) {
        if (s.senderId == uid ||
            _seenSos.contains(s.sosId) ||
            _sos.isDismissed(s.sosId)) {
          continue;
        }
        _seenSos.add(s.sosId);
        showIncomingSos(s, rideId);
      }
    });

    // Destination (one-shot-ish stream from the ride doc).
    _rideService.watchRide(rideId).listen((Ride? r) {
      final dest = r?.destination;
      destination.value = dest == null ? null : LatLng(dest.lat, dest.lng);
      plannedRoute.value = r?.plannedRoute;
      orderedStops.value = r?.orderedStops ?? <RideDestination>[];
    });

    // My route: recompute when I move ≥100m or go off-route.
    ever<LatLng?>(myLatLng, _maybeRouteMe);
    // Member routes: recompute when a member moves ≥100m.
    ever<List<MemberLocation>>(members, (List<MemberLocation> list) {
      for (final MemberLocation m in list) {
        if (m.uid == uid) continue;
        _maybeRouteMember(m);
      }
    });

    // Follow mode: re-center on the target whenever its position or heading updates,
    // but only while actively following (stops as soon as the user drags).
    ever<LatLng?>(myLatLng, (_) => _followIfActive());
    ever<List<MemberLocation>>(members, (_) => _followIfActive());
    ever<double>(myHeading, (_) => _followIfActive());

    ready.value = true;
  }

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
    final bool offRoute =
        myRoute.value != null &&
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

  /// The known route for a member (my own or another's), or null.
  RouteResult? routeFor(String memberUid) =>
      memberUid == uid ? myRoute.value : memberRoutes[memberUid];

  Future<void> sendSos() async {
    mySosId.value = await confirmAndSendSos(rideId);
  }

  Future<void> cancelSos() async {
    final String? id = mySosId.value;
    if (id != null) {
      await _sos.cancel(rideId, id);
      mySosId.value = null;
    }
  }

  bool get iHaveActiveSos =>
      mySosId.value != null &&
      activeSos.any((SosAlert s) => s.sosId == mySosId.value);

  RideMember? rideMemberFor(String memberUid) {
    for (final RideMember m in rideMembers) {
      if (m.uid == memberUid) return m;
    }
    return null;
  }

  LatLng? _followTargetPosition() {
    final String? target = followTarget.value;
    if (target == null) return myLatLng.value;
    for (final MemberLocation m in members) {
      if (m.uid == target) return LatLng(m.lat, m.lng);
    }
    return null;
  }

  double? _followTargetHeading() {
    final String? target = followTarget.value;
    if (target == null) return myHeading.value;
    for (final MemberLocation m in members) {
      if (m.uid == target) return m.heading;
    }
    return null;
  }

  /// Camera center for a Google-Maps-style nav view: pushed *ahead* of the
  /// target along its heading, so the marker sits in the lower third of the
  /// screen with the road ahead filling the top.
  LatLng _cameraCenterBehind(LatLng target, double heading) {
    return _dist.offset(target, _navAheadMeters, heading);
  }

  /// How far ahead of the marker to place the camera center. ~260m at the
  /// nav zoom (16.5) drops the marker to roughly the lower third of a phone
  /// screen; the "behind"/preview recenter uses a smaller shift.
  static const double _navAheadMeters = 260;

  /// "Start" button: begin Google-Maps-style navigation — lock the camera to
  /// the follow target (self by default) in the tilted nav view and keep it
  /// glued there on every location fix.
  void startTracking() {
    if (_isDisposed) return;
    isTracking.value = true;
    _startFollowing(target: followTarget.value);
  }

  /// "Stop"/"End" button: leave navigation and return to a free preview map.
  void stopTracking() {
    if (_isDisposed) return;
    isTracking.value = false;
    isFollowing.value = false;
    showRecenter.value = false;
  }

  void _startFollowing({String? target}) {
    if (_isDisposed) return;
    Log.d('_startFollowing called with target: $target');
    followTarget.value = target;
    isFollowing.value = true;
    showRecenter.value = false;
    final LatLng? pos = _followTargetPosition();
    if (pos == null) {
      Log.d('_startFollowing: no position found for target $target');
      return;
    }
    final double heading = _followTargetHeading() ?? 0;
    Log.d(
      '_startFollowing: animating to lat: ${pos.latitude}, lng: ${pos.longitude}, heading: $heading',
    );
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: 16.5,
      rotation: -heading,
    );
  }

  void _followIfActive() {
    if (_isDisposed) return;
    if (!isTracking.value || !isFollowing.value) return;
    final LatLng? pos = _followTargetPosition();
    if (pos == null) {
      Log.d('_followIfActive: no position');
      return;
    }
    final double heading = _followTargetHeading() ?? 0;
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: mapController.camera.zoom,
      rotation: -heading,
      // Glide over ~the fix cadence so movement looks continuous, not steppy.
      duration: const Duration(milliseconds: 900),
    );
  }

  void zoomIn({bool keepFollowing = false}) {
    if (_isDisposed) return;
    if (!keepFollowing)
      onMapDragged(); // Stop following when zooming via button
    final double newZoom = mapController.camera.zoom + 1;
    zoomLevel.value = newZoom;
    animatedMapController.animateTo(
      dest: mapController.camera.center,
      zoom: newZoom,
      rotation: mapController.camera.rotation,
    );
  }

  void zoomOut({bool keepFollowing = false}) {
    if (_isDisposed) return;
    if (!keepFollowing)
      onMapDragged(); // Stop following when zooming via button
    final double newZoom = mapController.camera.zoom - 1;
    zoomLevel.value = newZoom;
    animatedMapController.animateTo(
      dest: mapController.camera.center,
      zoom: newZoom,
      rotation: mapController.camera.rotation,
    );
  }

  /// One-shot overview: frame all members + me + destination. Stops follow
  /// (like a manual gesture) so the auto-follow loop won't yank the camera.
  void fitAll() {
    if (_isDisposed) return;
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

  /// Recenter FAB: resume following the target (self by default, or a specific
  /// member). If the target member is no longer available, falls back to self.
  /// Animates the camera to center behind the target with a 16.5 zoom.
  void recenter() {
    if (_isDisposed) return;
    isTracking.value = true;
    isFollowing.value = true;
    showRecenter.value = false;
    // Resolve target position – fallback to self if member not found
    LatLng? pos = _followTargetPosition();
    if (pos == null) {
      // Target member might have left – reset to self
      followTarget.value = null;
      pos = myLatLng.value;
      if (pos == null) return;
    }
    final double heading = _followTargetHeading() ?? 0;
    Log.d('recenter: target=${followTarget.value}, heading=$heading');
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: 16.5,
      rotation: -heading,
    );
  }

  /// Members list tap: enter navigation following this specific member.
  void followMember(MemberLocation m) {
    if (_isDisposed) return;
    isTracking.value = true;
    _startFollowing(target: m.uid);
  }

  /// Called when the user drags/pinches/zooms the map — stops auto-follow so
  /// we don't fight their gesture, and immediately reveals the recenter button
  /// (Google-Maps-style, on the very first interaction).
  void onMapDragged() {
    isFollowing.value = false;
    showRecenter.value = true;
  }

  /// Update zoom level from map position changes
  void updateZoomLevel(double newZoom) {
    zoomLevel.value = newZoom;
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  void onClose() {
    _isDisposed = true;
    animatedMapController.dispose();
    _rideLoc.stopSharing(rideId);
    super.onClose();
  }
}
