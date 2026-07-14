import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
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

class RideMapController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final LocationService _loc = Get.find<LocationService>();
  final RideLocationService _rideLoc = Get.find<RideLocationService>();
  final RoutingService _routing = Get.find<RoutingService>();
  final RideService _rideService = Get.find<RideService>();
  final ChatService _chat = Get.find<ChatService>();
  final SosService _sos = Get.find<SosService>();
  final AuthService _auth = Get.find<AuthService>();
  final String rideId;
  RideMapController(this.rideId);

  late final AnimatedMapController animatedMapController;

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
  final RxBool isFollowing = true.obs;

  // --- Phase 6: SOS ---
  final RxList<SosAlert> activeSos = <SosAlert>[].obs;
  final RxnString mySosId = RxnString();
  final Set<String> _seenSos = <String>{};

  // --- Phase 4: routing ---
  final Rxn<RouteResult> myRoute = Rxn<RouteResult>();
  final RxMap<String, RouteResult> memberRoutes = <String, RouteResult>{}.obs;
  final RxBool rerouting = false.obs;
  final Rxn<LatLng> destination = Rxn<LatLng>();
  final Distance _dist = const Distance();
  final Map<String, LatLng> _lastRoutedFrom = <String, LatLng>{};

  bool get hasDestination => destination.value != null;

  String? get uid => _auth.uid;

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

  Future<void> _start() async {
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
        if (s.senderId == uid || _seenSos.contains(s.sosId)) continue;
        _seenSos.add(s.sosId);
        showIncomingSos(s, rideId);
      }
    });

    // Destination (one-shot-ish stream from the ride doc).
    _rideService.watchRide(rideId).listen((Ride? r) {
      final dest = r?.destination;
      destination.value = dest == null ? null : LatLng(dest.lat, dest.lng);
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

    // Follow mode: re-center on the target whenever its position updates,
    // but only while actively following (stops as soon as the user drags).
    ever<LatLng?>(myLatLng, (_) => _followIfActive());
    ever<List<MemberLocation>>(members, (_) => _followIfActive());

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

  LatLng _cameraCenterBehind(LatLng target, double heading) {
    return _dist.offset(target, 120, heading + 180);
  }

  void _startFollowing({String? target}) {
    followTarget.value = target;
    isFollowing.value = true;
    final LatLng? pos = _followTargetPosition();
    if (pos == null) return;
    final double heading = _followTargetHeading() ?? 0;
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: 16,
      rotation: -heading,
    );
  }

  void _followIfActive() {
    if (!isFollowing.value) return;
    final LatLng? pos = _followTargetPosition();
    if (pos == null) return;
    final double heading = _followTargetHeading() ?? 0;
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: mapController.camera.zoom,
      rotation: -heading,
    );
  }

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

  /// Recenter FAB: resume following the last target (self, or a member if
  /// one was previously selected).
  void recenter() => _startFollowing(target: followTarget.value);

  /// Members list tap: start following this specific member.
  void followMember(MemberLocation m) => _startFollowing(target: m.uid);

  /// Called when the user drags/pinches the map — stops auto-follow so we
  /// don't fight their gesture. The recenter FAB reappears in its
  /// actionable state; tapping it resumes following [followTarget].
  void onMapDragged() => isFollowing.value = false;

  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  void onClose() {
    animatedMapController.dispose();
    _rideLoc.stopSharing(rideId);
    super.onClose();
  }
}
