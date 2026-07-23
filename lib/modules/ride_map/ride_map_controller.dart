import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../core/utils/logger.dart';
import '../../models/member_location.dart';
import '../../models/ride.dart';
import '../../models/ride_alert.dart';
import '../../models/ride_member.dart';
import '../../models/ride_memory.dart';
import '../../models/ride_position.dart';
import '../../models/route_result.dart';
import '../../models/sos_alert.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_location_service.dart';
import '../../services/ride_memory_service.dart';
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
  final RideMemoryService _memoryService = Get.find<RideMemoryService>();
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

  /// Shared trip memories (pins + logs) for this ride.
  final RxList<RideMemory> memories = <RideMemory>[].obs;

  /// The current ride doc — held so the map knows who the host is (for
  /// delete-any-memory rights) alongside its destination/route reads.
  final Rxn<Ride> ride = Rxn<Ride>();
  bool get amHost => uid != null && (ride.value?.isHost(uid!) ?? false);
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
  final RxDouble zoomLevel = 12.0.obs;

  // --- Transient in-app alerts (overtake / offline / off-route / arrived +
  // a periodic per-member status digest). Shown as slide-in cards over the map
  // by the view; each is auto-dismissed after its ttl. ---
  final RxList<RideAlert> alerts = <RideAlert>[].obs;
  int _alertSeq = 0;

  /// Per-member snapshots used to detect *transitions* (so we alert once, on
  /// change, not every fix).
  final Map<String, double> _lastDestDist = <String, double>{}; // meters
  final Map<String, bool> _wasOnline = <String, bool>{};
  final Map<String, bool> _wasOffRoute = <String, bool>{};
  final Set<String> _arrived = <String>{};
  final Set<String> _overtaken = <String>{}; // members already ahead of me

  /// How close (m) to the destination counts as "arrived".
  static const double _arriveMeters = 100;

  /// How far (m) off the route counts as "off route".
  static const double _offRouteMeters = 150;

  /// Periodic status digest timer + which member to report next (round-robin).
  Timer? _statusTimer;
  int _statusCursor = 0;

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

    // Keep my own dot fresh, and share to RTDB, from the SAME battery-aware
    // stream — two separate positionStream() calls would each run their own
    // independent GPS poll loop, out of phase with each other, so "my dot"
    // and what gets written to RTDB would drift apart and double GPS calls.
    final Stream<RidePosition> myPosition = _loc.positionStream().asBroadcastStream();
    myPosition.listen((p) {
      myLatLng.value = LatLng(p.lat, p.lng);
      myHeading.value = p.heading;
    });
    _rideLoc.startSharing(rideId, myPosition);
    members.bindStream(_rideLoc.watchLocations(rideId));

    // Opened to focus a specific member (from Ride Detail / member sheet):
    // pan to them once their first location fix arrives, so the map opens on
    // THAT rider instead of me.
    if (initialFocusUid != null) {
      bool focused = false;
      ever<List<MemberLocation>>(members, (List<MemberLocation> list) {
        if (focused || _isDisposed) return;
        for (final MemberLocation m in list) {
          if (m.uid == initialFocusUid) {
            focused = true;
            animatedMapController.animateTo(
              dest: LatLng(m.lat, m.lng),
              zoom: 16,
            );
            showRecenter.value = true;
            break;
          }
        }
      });
    }
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
      ride.value = r;
      final dest = r?.destination;
      destination.value = dest == null ? null : LatLng(dest.lat, dest.lng);
      plannedRoute.value = r?.plannedRoute;
      orderedStops.value = r?.orderedStops ?? <RideDestination>[];
    });

    // Shared trip memories (pins + logs) — everyone in the ride sees them.
    memories.bindStream(_memoryService.watch(rideId));

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

    // Transient alerts: inspect each members fix for events (overtake / offline
    // / off-route / arrived).
    ever<List<MemberLocation>>(members, _detectAlerts);
    // Periodic per-member status digest every 2 minutes.
    _statusTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _emitStatusDigest(),
    );

    ready.value = true;
  }

  // ---------------------------------------------------------------------------
  // Transient alerts
  // ---------------------------------------------------------------------------

  void _pushAlert(RideAlertType type, String title, String message) {
    if (_isDisposed) return;
    final RideAlert alert = RideAlert(
      id: _alertSeq++,
      type: type,
      title: title,
      message: message,
    );
    alerts.add(alert);
    // Keep the stack short so cards never pile up on screen.
    if (alerts.length > 3) alerts.removeAt(0);
    // Auto-dismiss after the alert's ttl.
    Timer(alert.ttl, () => dismissAlert(alert.id));
  }

  /// Removes an alert (auto after ttl, or when the user swipes it away).
  void dismissAlert(int id) {
    if (_isDisposed) return;
    alerts.removeWhere((RideAlert a) => a.id == id);
  }

  String _nameFor(String memberUid) =>
      rideMemberFor(memberUid)?.name ?? 'A rider';

  /// My own remaining distance to the destination (meters), or null if unknown.
  double? get _myDestMeters => myRoute.value?.distanceMeters;

  /// A member's remaining distance to the destination (meters): prefer their
  /// computed route, else straight-line to the destination.
  double? _memberDestMeters(MemberLocation m) {
    final RouteResult? r = memberRoutes[m.uid];
    if (r != null) return r.distanceMeters;
    final LatLng? dest = destination.value;
    if (dest == null) return null;
    return _meters(LatLng(m.lat, m.lng), dest);
  }

  void _detectAlerts(List<MemberLocation> list) {
    if (_isDisposed) return;
    final LatLng? dest = destination.value;
    for (final MemberLocation m in list) {
      if (m.uid == uid) continue;

      // --- Offline transition ---
      final bool wasOnline = _wasOnline[m.uid] ?? m.online;
      if (wasOnline && !m.online) {
        _pushAlert(
          RideAlertType.offline,
          '${_nameFor(m.uid)} offline',
          '${_nameFor(m.uid)} abhi offline hai — location update ruk gaya.',
        );
      }
      _wasOnline[m.uid] = m.online;

      if (dest != null) {
        final LatLng pos = LatLng(m.lat, m.lng);
        final double destDist = _meters(pos, dest);

        // --- Arrived (once) ---
        if (destDist <= _arriveMeters && !_arrived.contains(m.uid)) {
          _arrived.add(m.uid);
          _pushAlert(
            RideAlertType.arrived,
            '${_nameFor(m.uid)} pohch gaya',
            '${_nameFor(m.uid)} destination pe pohch gaya.',
          );
        } else if (destDist > _arriveMeters * 3) {
          // Left the area again — allow a future "arrived" alert.
          _arrived.remove(m.uid);
        }

        // --- Overtake: crosses ahead of me (closer to dest than I am) ---
        final double? mine = _myDestMeters;
        final double? theirs = _memberDestMeters(m);
        if (mine != null && theirs != null) {
          final bool aheadNow = theirs < mine;
          final bool wasAhead = _overtaken.contains(m.uid);
          if (aheadNow && !wasAhead && m.online) {
            _overtaken.add(m.uid);
            final String gap = _distText((mine - theirs).abs());
            _pushAlert(
              RideAlertType.overtake,
              '${_nameFor(m.uid)} ne overtake kiya',
              '${_nameFor(m.uid)} ab aapse $gap aage hai.',
            );
          } else if (!aheadNow && wasAhead) {
            _overtaken.remove(m.uid); // fell back behind me
          }
        }

        _lastDestDist[m.uid] = destDist;
      }

      // --- Off-route transition ---
      final List<LatLng>? route =
          (plannedRoute.value != null && plannedRoute.value!.length >= 2)
              ? plannedRoute.value
              : memberRoutes[m.uid]?.points;
      if (route != null && route.length >= 2) {
        final double d = _distanceToRoute(LatLng(m.lat, m.lng), route);
        final bool offNow = d > _offRouteMeters;
        final bool wasOff = _wasOffRoute[m.uid] ?? false;
        if (offNow && !wasOff && m.online) {
          _pushAlert(
            RideAlertType.offRoute,
            '${_nameFor(m.uid)} route se hata',
            '${_nameFor(m.uid)} route se ${_distText(d)} door chala gaya.',
          );
        }
        _wasOffRoute[m.uid] = offNow;
      }
    }
  }

  /// Round-robin: every tick, report one member's distance / ETA to the
  /// destination and how far ahead/behind me they are.
  void _emitStatusDigest() {
    if (_isDisposed) return;
    final List<MemberLocation> others =
        members.where((MemberLocation m) => m.uid != uid).toList();
    if (others.isEmpty || destination.value == null) return;

    final MemberLocation m = others[_statusCursor % others.length];
    _statusCursor++;

    final double? theirs = _memberDestMeters(m);
    if (theirs == null) return;
    final RouteResult? r = memberRoutes[m.uid];
    final String eta = r != null ? ' · ${r.etaText} me pohchega' : '';

    final double? mine = _myDestMeters;
    String gap = '';
    if (mine != null) {
      final double diff = (mine - theirs).abs();
      if (diff > 50) {
        gap = theirs < mine
            ? ' · aap ${_distText(diff)} piche'
            : ' · aap ${_distText(diff)} aage';
      } else {
        gap = ' · aap saath-saath';
      }
    }

    _pushAlert(
      RideAlertType.status,
      _nameFor(m.uid),
      'Destination se ${_distText(theirs)}$eta$gap',
    );
  }

  /// Compact distance label (matches [RouteResult.distanceText] style).
  String _distText(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

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

  /// Follow target's speed in km/h (self has no live speed → treat as 0).
  double _followTargetSpeedKmh() {
    final String? target = followTarget.value;
    if (target == null) return 0;
    for (final MemberLocation m in members) {
      if (m.uid == target) return m.speedKmh;
    }
    return 0;
  }

  /// Below this speed the follow target is treated as stationary: like Google
  /// Maps, we then center the marker (no ahead-offset) and keep the map
  /// north-up instead of spinning to a stale/meaningless heading.
  static const double _movingThresholdKmh = 3;

  /// Whether the follow target is moving fast enough for the tilted,
  /// heading-rotated nav view.
  bool get _targetMoving => _followTargetSpeedKmh() >= _movingThresholdKmh;

  /// Camera center for a Google-Maps-style nav view: while moving, pushed
  /// *ahead* of the target along its heading so the marker sits in the lower
  /// third with the road ahead on top. While stationary, centered on the
  /// target (no offset).
  LatLng _cameraCenterBehind(LatLng target, double heading) {
    if (!_targetMoving) return target;
    return _dist.offset(target, _navAheadMeters, heading);
  }

  /// Map rotation for the follow view: aligned to the direction of travel
  /// while moving, north-up (0) while stationary — matches Google Maps.
  double _followRotation(double heading) => _targetMoving ? -heading : 0;

  /// How far ahead of the marker to place the camera center. ~260m at the
  /// nav zoom (16) drops the marker to roughly the lower third of a phone
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
  /// Zooms back out to the default preview zoom (12) and levels the rotation.
  void stopTracking() {
    if (_isDisposed) return;
    isTracking.value = false;
    isFollowing.value = false;
    showRecenter.value = false;
    followTarget.value = null;
    zoomLevel.value = 12;
    animatedMapController.animateTo(
      dest: mapController.camera.center,
      zoom: 12,
      rotation: 0,
    );
  }

  void _startFollowing({String? target}) {
    if (_isDisposed) return;
    Log.d('_startFollowing called with target: $target');
    followTarget.value = target;
    isFollowing.value = true;
    showRecenter.value = false;
    zoomLevel.value = 16;
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
      zoom: 16,
      rotation: _followRotation(heading),
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
      rotation: _followRotation(heading),
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
  /// Animates the camera to center behind the target with a 16 zoom.
  void recenter() {
    if (_isDisposed) return;
    showRecenter.value = false;

    // Preview mode (navigation not started): just re-center on myself,
    // north-up, keeping the current zoom — don't silently start navigation.
    if (!isTracking.value) {
      final LatLng? me = myLatLng.value;
      if (me == null) return;
      animatedMapController.animateTo(
        dest: me,
        zoom: mapController.camera.zoom,
        rotation: 0,
      );
      return;
    }

    isFollowing.value = true;
    // Resolve target position – fallback to self if member not found
    LatLng? pos = _followTargetPosition();
    if (pos == null) {
      // Target member might have left – reset to self
      followTarget.value = null;
      pos = myLatLng.value;
      if (pos == null) return;
    }
    final double heading = _followTargetHeading() ?? 0;
    // Keep the user's current zoom if they've already zoomed in past the
    // default nav zoom; otherwise snap to 16 (Google-Maps recenter feel).
    final double currentZoom = mapController.camera.zoom;
    final double zoom = currentZoom > 16 ? currentZoom : 16;
    zoomLevel.value = zoom;
    Log.d('recenter: target=${followTarget.value}, heading=$heading');
    animatedMapController.animateTo(
      dest: _cameraCenterBehind(pos, heading),
      zoom: zoom,
      rotation: _followRotation(heading),
    );
  }

  /// Members list tap: change who we follow. Navigation itself only starts
  /// from the Start button — so if we're already navigating, re-lock the
  /// camera onto this member; if not, just switch the target and pan the
  /// preview to them (no nav lock, keep current zoom).
  void followMember(MemberLocation m) {
    if (_isDisposed) return;
    followTarget.value = m.uid;
    if (isTracking.value) {
      _startFollowing(target: m.uid);
      return;
    }
    // Preview: pan straight to THIS member's own coordinates (use the tapped
    // record directly so we never fall back to my own location). Zoom in a bit
    // if we're still at the far-out preview zoom so the rider is clearly seen.
    final LatLng pos = LatLng(m.lat, m.lng);
    final double currentZoom = mapController.camera.zoom;
    animatedMapController.animateTo(
      dest: pos,
      zoom: currentZoom < 15 ? 16 : currentZoom,
      rotation: 0,
    );
    // Show the recenter button so the user can jump back to their own view.
    showRecenter.value = true;
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
    _statusTimer?.cancel();
    animatedMapController.dispose();
    _rideLoc.stopSharing(rideId);
    super.onClose();
  }
}
