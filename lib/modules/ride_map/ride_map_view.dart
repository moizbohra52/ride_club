import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../models/member_location.dart';
import '../../models/ride.dart';
import '../../models/ride_member.dart';
import '../../models/route_result.dart';
import '../../routes/app_routes.dart';
import '../../widgets/gradient_button.dart';
import '../rides/member_detail_sheet.dart';
import 'ride_map_controller.dart';

class RideMapView extends GetView<RideMapController> {
  const RideMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live map'),
        actions: <Widget>[
          Obx(() {
            final int n = controller.unread.value;
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: 'Ride chat',
                  onPressed: () =>
                      Get.toNamed(Routes.chat, arguments: controller.rideId),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                if (n > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.sos,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        n > 9 ? '9+' : '$n',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        if (!controller.ready.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.permissionError.value != null) {
          return _permissionError(context);
        }
        final LatLng center =
            controller.myLatLng.value ??
            const LatLng(20.5937, 78.9629); // India fallback
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final String tileUrl = isDark
            ? AppConstants.osmTileUrlDark
            : AppConstants.osmTileUrl;
        return Stack(
          children: <Widget>[
            FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                onPositionChanged: (MapCamera camera, bool hasGesture) {
                  controller.updateZoomLevel(camera.zoom);
                  if (hasGesture) controller.onMapDragged();
                },
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: AppConstants.userAgentPackageName,
                ),
                Obx(() => PolylineLayer(polylines: _routePolylines(isDark))),
                // Static markers (me + stops) snap instantly; other members'
                // markers glide between fixes for a Google-Maps-style feel.
                Obx(
                  () => MarkerLayer(markers: _staticMarkers(context, isDark)),
                ),
                Obx(
                  () => _AnimatedMemberMarkers(
                    specs: _memberMarkerSpecs(context, isDark),
                    counterRotation:
                        -controller.mapController.camera.rotation *
                        (math.pi / 180),
                  ),
                ),
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
                        onTap: () => launchUrl(
                          Uri.parse('https://carto.com/attributions'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // Overlay chrome. Everything anchors to top or bottom via Columns
            // (not fixed pixel offsets) so nothing overlaps on any screen size
            // and the map stays as large as possible.
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    // ── Top: info card, then SOS banner stacked below it ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _infoCard(context),
                          Obx(
                            () => controller.iHaveActiveSos
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _sosBanner(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Right-side floating controls, sitting just above the
                    // bottom bar (SOS on the left of the same row). ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          _pulsingSosFab(onPressed: controller.sendSos),
                          const Spacer(),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // Recenter — appears the instant the user moves
                              // the map (pan/zoom/rotate), Google-Maps-style.
                              Obx(() {
                                final bool show = controller.showRecenter.value;
                                return IgnorePointer(
                                  ignoring: !show,
                                  child: AnimatedOpacity(
                                    opacity: show ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 150),
                                    child: AnimatedScale(
                                      scale: show ? 1.0 : 0.0,
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      curve: Curves.easeOutBack,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _MapControlButton(
                                          icon: Icons.my_location_rounded,
                                          tooltip: 'Recenter map',
                                          onTap: controller.recenter,
                                          isPrimary: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              _MapControlButton(
                                icon: Icons.fit_screen_rounded,
                                tooltip: 'Fit all riders',
                                onTap: controller.fitAll,
                              ),
                              const SizedBox(height: 10),
                              Obx(
                                () => _MapControlPill(
                                  zoomLevel: controller.zoomLevel.value,
                                  onZoomIn: () =>
                                      controller.zoomIn(keepFollowing: true),
                                  onZoomOut: () =>
                                      controller.zoomOut(keepFollowing: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Bottom bar: Start/Stop + Members ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Obx(
                        () => Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: controller.isTracking.value
                                  ? _stopNavButton(context)
                                  : _startNavButton(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(flex: 3, child: _membersBar(context)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _startNavButton(BuildContext context) => GradientButton(
    label: 'Start',
    icon: Icons.navigation_rounded,
    onTap: controller.startTracking,
    height: 50,
  );

  Widget _stopNavButton(BuildContext context) {
    // Solid, filled "End" button: a soft red that reads as the stop state
    // without competing with the SOS control. Same height/shape as Start.
    const Color stopColor = AppColors.danger;
    return Material(
      elevation: 4,
      shadowColor: stopColor.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      color: stopColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          controller.stopTracking();
        },
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'End',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Polyline> _routePolylines(bool isDark) {
    final List<Polyline> lines = <Polyline>[];
    final List<LatLng>? planned = controller.plannedRoute.value;

    // Thick, solid, dark decent lines — no alpha glow layers. Each route is a
    // white casing (edge) under one solid colored line.
    const double casingWidth = 11;
    const double lineWidth = 7;
    const double memberCasingWidth = 9;
    const double memberLineWidth = 5.5;

    if (planned != null && planned.length >= 2) {
      // Current user's path on the planned route.
      lines.add(
        Polyline(
          points: planned,
          color: AppColors.routeCasing.withValues(alpha: isDark ? 0.25 : 0.9),
          strokeWidth: casingWidth,
        ),
      );
      lines.add(
        Polyline(
          points: planned,
          color: isDark ? AppColors.coralSoft : AppColors.routeLine,
          strokeWidth: lineWidth,
        ),
      );

      // Other members' paths on the same planned route, offset per member.
      final List<MemberLocation> otherMembers = controller.members
          .where((MemberLocation m) => m.uid != controller.uid)
          .toList();
      for (final MemberLocation m in otherMembers) {
        final Color memberColor = AppColors.memberRouteColorForKey(m.uid);
        final double offsetAmount = _offsetAmountFor(m.uid);
        final List<LatLng> offsetPoints = _offsetPoints(planned, offsetAmount);

        lines.add(
          Polyline(
            points: offsetPoints,
            color: AppColors.routeCasing.withValues(alpha: isDark ? 0.2 : 0.8),
            strokeWidth: memberCasingWidth,
          ),
        );
        lines.add(
          Polyline(
            points: offsetPoints,
            color: memberColor,
            strokeWidth: memberLineWidth,
          ),
        );
      }
    } else {
      // Fallback: draw individual routes when no planned route exists.
      final RouteResult? myR = controller.myRoute.value;
      if (myR != null) {
        lines.add(
          Polyline(
            points: myR.points,
            color: AppColors.routeCasing.withValues(alpha: isDark ? 0.25 : 0.9),
            strokeWidth: casingWidth,
          ),
        );
        lines.add(
          Polyline(
            points: myR.points,
            color: isDark ? AppColors.coralSoft : AppColors.routeLine,
            strokeWidth: lineWidth,
          ),
        );
      }
      controller.memberRoutes.forEach((String uid, RouteResult route) {
        final Color memberColor = AppColors.memberRouteColorForKey(uid);
        final double offsetAmount = _offsetAmountFor(uid);
        final List<LatLng> offsetPoints = _offsetPoints(
          route.points,
          offsetAmount,
        );

        lines.add(
          Polyline(
            points: offsetPoints,
            color: AppColors.routeCasing.withValues(alpha: isDark ? 0.2 : 0.8),
            strokeWidth: memberCasingWidth,
          ),
        );
        lines.add(
          Polyline(
            points: offsetPoints,
            color: memberColor,
            strokeWidth: memberLineWidth,
          ),
        );
      });
    }
    return lines;
  }

  /// Deterministic left/right offset (±5m) for a member, keyed only by their
  /// uid — independent of iteration order — so the same member always gets
  /// the same offset side in both the polyline and its marker.
  double _offsetAmountFor(String uid) => uid.hashCode.isEven ? 5 : -5;

  /// Offsets a list of LatLng points by a small distance perpendicular to the route direction
  List<LatLng> _offsetPoints(List<LatLng> points, double offsetMeters) {
    if (points.length < 2) return points;

    final List<LatLng> offsetPoints = <LatLng>[];
    const Distance distance = Distance();

    for (int i = 0; i < points.length; i++) {
      LatLng current = points[i];
      double bearing;

      if (i == 0) {
        // First point: use direction to next point
        bearing = distance.bearing(points[i], points[i + 1]);
      } else if (i == points.length - 1) {
        // Last point: use direction from previous point
        bearing = distance.bearing(points[i - 1], points[i]);
      } else {
        // Middle point: average of directions from previous and to next
        final double b1 = distance.bearing(points[i - 1], points[i]);
        final double b2 = distance.bearing(points[i], points[i + 1]);
        bearing = (b1 + b2) / 2;
      }

      // Offset perpendicular to bearing (90 degrees clockwise)
      final double offsetBearing = (bearing + 90) % 360;
      final LatLng offsetPoint = distance.offset(
        current,
        offsetMeters,
        offsetBearing,
      );
      offsetPoints.add(offsetPoint);
    }

    return offsetPoints;
  }

  /// Finds where [pos] sits along [routePoints] (nearest segment) and returns
  /// that same spot shifted perpendicular to the route by [offsetMeters] —
  /// i.e. the point on the offset line (see [_offsetPoints]) closest to
  /// [pos], so a member's marker always sits on the line drawn for them
  /// instead of at their raw, unoffset GPS position.
  LatLng _nearestOffsetPoint(
    LatLng pos,
    List<LatLng> routePoints,
    double offsetMeters,
  ) {
    const Distance distance = Distance();
    double bestDist = double.infinity;
    LatLng bestPoint = routePoints.first;
    double bestBearing = 0;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final LatLng a = routePoints[i];
      final LatLng b = routePoints[i + 1];
      final double segBearing = distance.bearing(a, b);
      final double segLengthMeters = distance.as(LengthUnit.Meter, a, b);
      if (segLengthMeters == 0) continue;

      // Project pos onto segment a→b (in meters, via equirectangular approx
      // over this short segment) to find the closest point on it.
      final double toPosBearing = distance.bearing(a, pos);
      final double toPosMeters = distance.as(LengthUnit.Meter, a, pos);
      final double angleRad = (toPosBearing - segBearing) * math.pi / 180;
      double along = toPosMeters * math.cos(angleRad);
      along = along.clamp(0, segLengthMeters);
      final LatLng candidate = along == 0
          ? a
          : distance.offset(a, along, segBearing);
      final double d = distance.as(LengthUnit.Meter, pos, candidate);
      if (d < bestDist) {
        bestDist = d;
        bestPoint = candidate;
        bestBearing = segBearing;
      }
    }

    final double offsetBearing = (bestBearing + 90) % 360;
    return distance.offset(bestPoint, offsetMeters, offsetBearing);
  }

  Widget _infoCard(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final String text;
      if (!controller.hasDestination) {
        text = 'Set a destination to see routes';
      } else if (controller.myRoute.value != null) {
        final RouteResult r = controller.myRoute.value!;
        text = 'To destination · ${r.distanceText} · ${r.etaText}';
      } else {
        text = 'Finding your route…';
      }
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.navigation_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (controller.rerouting.value)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _sosBanner() => Material(
    color: AppColors.sos,
    elevation: 6,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: controller.cancelSos,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SOS active · Tap to cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// A pulsing SOS FAB: a soft repeating glow halo draws the eye to the
  /// emergency control without being distracting. Tapping fires [onPressed].
  Widget _pulsingSosFab({required VoidCallback onPressed}) =>
      _SosFab(onPressed: onPressed);

  /// Markers that snap instantly: the user's own location and the route
  /// stops/waypoints. Other members are drawn by [_AnimatedMemberMarkers] so
  /// they glide between fixes.
  List<Marker> _staticMarkers(BuildContext context, bool isDark) {
    final List<Marker> markers = <Marker>[];
    final double counterRotation =
        -controller.mapController.camera.rotation * (math.pi / 180);

    // Always show your own location as a marker
    final LatLng? me = controller.myLatLng.value;
    if (me != null) {
      final RideMember? myProfile = controller.uid == null
          ? null
          : controller.rideMemberFor(controller.uid!);
      // Following myself while navigating → show the direction arrow instead
      // of my profile pin.
      final bool arrowMode =
          controller.isTracking.value && controller.followTarget.value == null;
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
              arrowMode: arrowMode,
            ),
          ),
        ),
      );
    }

    final List<RideDestination> stops = controller.orderedStops;
    for (int i = 0; i < stops.length; i++) {
      final RideDestination s = stops[i];
      final bool isFirst = i == 0;
      final bool isLast = i == stops.length - 1;
      final Widget pin;
      if (isFirst && stops.length > 1) {
        pin = const Icon(Icons.trip_origin, color: AppColors.success, size: 30);
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
    // Route arrows removed
    return markers;
  }

  /// Build a spec per other member: the target point (snapped onto their
  /// offset route line) plus the pin widget. [_AnimatedMemberMarkers] glides
  /// each marker from its previous point to this target.
  List<_MemberMarkerSpec> _memberMarkerSpecs(
    BuildContext context,
    bool isDark,
  ) {
    final List<_MemberMarkerSpec> specs = <_MemberMarkerSpec>[];
    final List<LatLng>? planned = controller.plannedRoute.value;
    for (final MemberLocation m in controller.members) {
      if (m.uid == controller.uid) continue; // Don't duplicate the "me" marker
      final RideMember? profile = controller.rideMemberFor(m.uid);
      final RouteResult? route = controller.routeFor(m.uid);
      final RideMember resolved =
          profile ??
          RideMember(
            uid: m.uid,
            name: 'Rider',
            colorValue: AppColors.memberColorForKey(m.uid).toARGB32(),
            role: 'rider',
          );

      // Snap the marker onto the same offset line drawn for this member in
      // _routePolylines, so it never appears to drift off its own route.
      final List<LatLng>? memberRoutePoints =
          planned != null && planned.length >= 2
          ? planned
          : controller.memberRoutes[m.uid]?.points;
      final LatLng realPos = LatLng(m.lat, m.lng);
      final LatLng markerPoint =
          memberRoutePoints != null && memberRoutePoints.length >= 2
          ? _nearestOffsetPoint(
              realPos,
              memberRoutePoints,
              _offsetAmountFor(m.uid),
            )
          : realPos;

      specs.add(
        _MemberMarkerSpec(
          uid: m.uid,
          target: markerPoint,
          pin: GestureDetector(
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
              // While navigating and following THIS member: show the direction
              // arrow when they're online and moving; fall back to the profile
              // pin when they're offline (or standing still).
              arrowMode:
                  controller.isTracking.value &&
                  controller.followTarget.value == m.uid &&
                  m.online &&
                  m.speedKmh >= 1,
            ),
          ),
        ),
      );
    }
    return specs;
  }

  Widget _membersBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => _showMembers(context),
      child: Obx(
        () => Row(
          children: <Widget>[
            Icon(Icons.group_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              '${controller.members.length}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'riders',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.expand_less_rounded,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showMembers(BuildContext context) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: controller.members.map((MemberLocation m) {
                final RouteResult? route = controller.routeFor(m.uid);
                final String eta = route == null
                    ? ''
                    : ' · ${route.distanceText} · ${route.etaText}';
                final RideMember? profile = controller.rideMemberFor(m.uid);
                final String displayName =
                    profile?.name ??
                    (m.uid == controller.uid ? 'You' : 'Rider');
                final RideMember resolvedMember =
                    profile ??
                    RideMember(
                      uid: m.uid,
                      name: displayName,
                      colorValue: AppColors.memberColorForKey(m.uid).toARGB32(),
                      role: 'rider',
                    );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.memberColorForKey(
                        m.uid,
                      ).withValues(alpha: 0.15),
                      radius: 16,
                      child: Icon(
                        Icons.person,
                        color: AppColors.memberColorForKey(m.uid),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${m.speedKmh.toStringAsFixed(0)} km/h · ${m.battery}% · '
                      '${m.lastSeenText(now)}$eta',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'Member details',
                      onPressed: () => showMemberDetail(
                        context,
                        member: resolvedMember,
                        rideId: controller.rideId,
                        live: m,
                        route: route,
                      ),
                    ),
                    onTap: () {
                      Get.back();
                      controller.followMember(m);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }

  Widget _permissionError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.location_off_rounded,
              size: 56,
              color: AppColors.sos,
            ),
            const SizedBox(height: 16),
            Text(
              controller.permissionError.value!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: controller.openSettings,
              child: const Text('Open settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One other-member marker to render: where it should be ([target]) and the
/// pin widget to show there. Keyed by [uid] so [_AnimatedMemberMarkers] can
/// glide the same member from its previous position.
class _MemberMarkerSpec {
  final String uid;
  final LatLng target;
  final Widget pin;
  const _MemberMarkerSpec({
    required this.uid,
    required this.target,
    required this.pin,
  });
}

/// Renders other members' markers and smoothly glides each one from its
/// previous position to the new one whenever a fresh location fix arrives,
/// instead of letting it jump (Google-Maps-style continuous movement).
class _AnimatedMemberMarkers extends StatefulWidget {
  final List<_MemberMarkerSpec> specs;
  final double counterRotation;
  const _AnimatedMemberMarkers({
    required this.specs,
    required this.counterRotation,
  });

  @override
  State<_AnimatedMemberMarkers> createState() => _AnimatedMemberMarkersState();
}

class _AnimatedMemberMarkersState extends State<_AnimatedMemberMarkers>
    with SingleTickerProviderStateMixin {
  static const Duration _glide = Duration(milliseconds: 900);

  // A single shared ticker drives every member's glide, so we rebuild the
  // marker layer at most once per frame no matter how many members there are.
  late final AnimationController _controller;

  // Per-member glide endpoints. On each fix we snapshot where the marker is
  // now (_from) and where it's heading (_to); build() lerps by _controller.value.
  final Map<String, LatLng> _from = <String, LatLng>{};
  final Map<String, LatLng> _to = <String, LatLng>{};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _glide)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    for (final _MemberMarkerSpec s in widget.specs) {
      _from[s.uid] = s.target;
      _to[s.uid] = s.target;
    }
  }

  @override
  void didUpdateWidget(_AnimatedMemberMarkers old) {
    super.didUpdateWidget(old);

    // Freeze current on-screen positions as the new "from", set new targets as
    // "to", and (re)start the shared glide only if something actually moved.
    final Set<String> present = <String>{};
    bool changed = false;
    final double t = _controller.value;
    for (final _MemberMarkerSpec s in widget.specs) {
      present.add(s.uid);
      final LatLng? to = _to[s.uid];
      if (to == null) {
        // New member — place without animating.
        _from[s.uid] = s.target;
        _to[s.uid] = s.target;
        continue;
      }
      if (to.latitude == s.target.latitude &&
          to.longitude == s.target.longitude) {
        continue; // target unchanged — no restart (ignores heading-only rebuilds)
      }
      final LatLng from = _from[s.uid] ?? to;
      // Current interpolated position becomes the new glide start.
      _from[s.uid] = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      _to[s.uid] = s.target;
      changed = true;
    }
    // Drop members who left.
    _from.removeWhere((String uid, _) => !present.contains(uid));
    _to.removeWhere((String uid, _) => !present.contains(uid));

    if (changed) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double t = _controller.value;
    final List<Marker> markers = <Marker>[];
    for (final _MemberMarkerSpec s in widget.specs) {
      final LatLng from = _from[s.uid] ?? s.target;
      final LatLng to = _to[s.uid] ?? s.target;
      final LatLng point = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      markers.add(
        Marker(
          key: ValueKey<String>(s.uid),
          point: point,
          width: 80,
          height: 80,
          child: Transform.rotate(angle: widget.counterRotation, child: s.pin),
        ),
      );
    }
    return MarkerLayer(markers: markers);
  }
}

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

  /// When true, render a bold navigation direction arrow (Google-Maps
  /// nav-style) instead of the profile avatar — used for the member being
  /// actively followed while they're online and moving.
  final bool arrowMode;
  const _MemberPin({
    required this.color,
    required this.heading,
    required this.speedKmh,
    required this.isMe,
    required this.photoUrl,
    required this.name,
    this.arrowMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (arrowMode) return _directionArrow();
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
                            placeholder: (BuildContext c, String u) =>
                                Container(color: color.withValues(alpha: 0.15)),
                            errorWidget: (BuildContext c, String u, Object e) =>
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

  /// Bold nav-style direction arrow, rotated to [heading], with an optional
  /// speed chip below — replaces the avatar for the actively-followed rider.
  Widget _directionArrow() => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0.7, end: 1),
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutBack,
    builder: (BuildContext context, double scale, Widget? child) =>
        Transform.scale(scale: scale, child: child),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Transform.rotate(
          angle: heading * math.pi / 180,
          child: CustomPaint(
            size: const Size(44, 44),
            painter: _NavArrowPainter(color: color),
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

/// A bold, filled navigation arrow (Google-Maps nav-style) inside a soft white
/// ring — points "up" at heading 0; the parent Transform.rotate turns it to
/// the real heading. Used for the actively-followed rider while moving.
class _NavArrowPainter extends CustomPainter {
  final Color color;
  _NavArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // White circular backing so the arrow reads on any map tile.
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Chevron/arrow pointing up.
    final Path arrow = Path()
      ..moveTo(cx, cy - r * 0.55) // tip
      ..lineTo(cx - r * 0.5, cy + r * 0.5) // bottom-left
      ..lineTo(cx, cy + r * 0.18) // notch
      ..lineTo(cx + r * 0.5, cy + r * 0.5) // bottom-right
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NavArrowPainter old) => old.color != color;
}

/// Modern map control button with gradient background and smooth animations.
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isPrimary;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: -40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      colors: AppColors.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isPrimary
                  ? null
                  : (isDark ? scheme.surfaceContainerHigh : scheme.surface),
              borderRadius: BorderRadius.circular(15),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isPrimary
                      ? AppColors.primaryGlow
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: isPrimary
                  ? null
                  : Border.all(
                      color: scheme.outlineVariant.withValues(
                        alpha: isDark ? 0.2 : 0.1,
                      ),
                      width: 1,
                    ),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : scheme.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern zoom control pill with zoom level indicator.
class _MapControlPill extends StatelessWidget {
  final double zoomLevel;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _MapControlPill({
    required this.zoomLevel,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 46,
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Zoom in button
          Tooltip(
            message: 'Zoom in',
            preferBelow: false,
            verticalOffset: -40,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onZoomIn();
              },
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: Container(
                width: 46,
                height: 42,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.seed,
                  size: 22,
                ),
              ),
            ),
          ),
          // Zoom level indicator
          Container(
            width: 32,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                zoomLevel.toStringAsFixed(0),
                style: GoogleFonts.poppins(
                  color: scheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
          // Zoom out button
          Tooltip(
            message: 'Zoom out',
            preferBelow: false,
            verticalOffset: -40,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onZoomOut();
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
              child: Container(
                width: 46,
                height: 42,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.remove_rounded,
                  color: AppColors.seed,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pulsing SOS FAB: a soft repeating glow halo draws the eye to the
/// emergency control without being distracting. Tapping fires [onPressed].
class _SosFab extends StatefulWidget {
  final VoidCallback onPressed;
  const _SosFab({required this.onPressed});

  @override
  State<_SosFab> createState() => _SosFabState();
}

class _SosFabState extends State<_SosFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Repeating glow halo.
          AnimatedBuilder(
            animation: _pulse,
            builder: (BuildContext context, Widget? child) {
              return Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sos.withValues(
                    alpha: 0.35 * (1 - _pulse.value),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _scale,
            builder: (BuildContext context, Widget? child) {
              return Transform.scale(scale: _scale.value, child: child);
            },
            child: FloatingActionButton.small(
              heroTag: 'sos',
              backgroundColor: AppColors.sos,
              elevation: 6,
              onPressed: widget.onPressed,
              child: const Icon(Icons.sos_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
