import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/member_location.dart';
import '../../models/ride_member.dart';
import '../../models/route_result.dart';
import '../../routes/app_routes.dart';
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
                          color: AppColors.sos, shape: BoxShape.circle),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        n > 9 ? '9+' : '$n',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
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
        final LatLng center = controller.myLatLng.value ??
            const LatLng(20.5937, 78.9629); // India fallback
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final String tileUrl =
            isDark ? AppConstants.osmTileUrlDark : AppConstants.osmTileUrl;
        return Stack(
          children: <Widget>[
            FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onPositionChanged: (MapCamera camera, bool hasGesture) {
                  if (hasGesture) controller.onMapDragged();
                },
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: AppConstants.userAgentPackageName,
                ),
                Obx(() => PolylineLayer(polylines: _routePolylines())),
                Obx(() => MarkerLayer(markers: _markers(context))),
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
            // SafeArea around widget overlays to prevent status/navigation bar clipping
            SafeArea(
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _infoCard(context),
                  ),
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
                  Positioned(
                    right: 16,
                    bottom: 96,
                    child: Obx(
                      () => FloatingActionButton(
                        heroTag: 'recenter',
                        backgroundColor: controller.isFollowing.value
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        foregroundColor: controller.isFollowing.value
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                        onPressed: controller.recenter,
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 96,
                    child: FloatingActionButton(
                      heroTag: 'sos',
                      backgroundColor: AppColors.sos,
                      onPressed: controller.sendSos,
                      child: const Icon(Icons.sos_rounded, color: Colors.white),
                    ),
                  ),
                  Obx(
                    () => controller.iHaveActiveSos
                        ? Positioned(
                            top: 80,
                            left: 16,
                            right: 16,
                            child: _sosBanner(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _membersBar(context),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  List<Polyline> _routePolylines() {
    final List<Polyline> lines = <Polyline>[];
    controller.memberRoutes.forEach((String uid, RouteResult route) {
      lines.add(
        Polyline(
          points: route.points,
          color: AppColors.memberColorForKey(uid).withValues(alpha: 0.4),
          strokeWidth: 3,
        ),
      );
    });
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
    return lines;
  }

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

  Widget _infoCard(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
      return Material(
        elevation: 6,
        shadowColor: AppColors.primaryGlow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        color: isDark ? scheme.surfaceContainerHigh.withValues(alpha: 0.9) : scheme.surface.withValues(alpha: 0.9),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(Icons.navigation_rounded, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

  List<Marker> _markers(BuildContext context) {
    final List<Marker> markers = <Marker>[];
    final double counterRotation = -controller.mapController.camera.rotation *
        (math.pi / 180);

    // Always show your own location as a marker
    final LatLng? me = controller.myLatLng.value;
    if (me != null) {
      final RideMember? myProfile = controller.uid == null
          ? null
          : controller.rideMemberFor(controller.uid!);
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
    markers.addAll(_routeArrows());
    return markers;
  }

  Widget _membersBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(18),
      color: isDark ? scheme.surfaceContainerHigh.withValues(alpha: 0.9) : scheme.surface.withValues(alpha: 0.9),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showMembers(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Obx(
            () => Row(
              children: <Widget>[
                Icon(Icons.group_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Text(
                  '${controller.members.length} on the map',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_less_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
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
                final String displayName = profile?.name ??
                    (m.uid == controller.uid ? 'You' : 'Rider');
                final RideMember resolvedMember = profile ??
                    RideMember(
                      uid: m.uid,
                      name: displayName,
                      colorValue:
                          AppColors.memberColorForKey(m.uid).toARGB32(),
                      role: 'rider',
                    );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.memberColorForKey(m.uid).withValues(alpha: 0.15),
                      radius: 16,
                      child: Icon(Icons.person, color: AppColors.memberColorForKey(m.uid)),
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
            const Icon(Icons.location_off_rounded, size: 56, color: AppColors.sos),
            const SizedBox(height: 16),
            Text(
              controller.permissionError.value!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
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
                            placeholder: (BuildContext c, String u) =>
                                Container(color: color.withValues(alpha: 0.15)),
                            errorWidget:
                                (BuildContext c, String u, Object e) =>
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
