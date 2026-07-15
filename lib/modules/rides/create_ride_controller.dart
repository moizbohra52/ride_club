import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/logger.dart';
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
        ?originD,
        ...waypointDs,
        ?destD,
      ];

      // TEMP DIAGNOSTIC (remove after debugging): what stops are chosen?
      Log.d(
        'create(): origin=${origin.chosen.value?.displayName} '
        'waypoints=${waypoints.length}(chosen ${waypointDs.length}) '
        'dest=${destination.chosen.value?.displayName} '
        'ordered=${ordered.length}',
      );

      List<LatLng>? plannedRoute;
      double? plannedDist;
      double? plannedDur;
      if (ordered.length >= 2) {
        final RouteResult? r = await _routing.routeMulti(
          ordered.map((RideDestination s) => LatLng(s.lat, s.lng)).toList(),
        );
        if (r != null) {
          plannedRoute = r.points;
          plannedDist = r.distanceMeters;
          plannedDur = r.durationSeconds;
        } else {
          UiHelpers.warning(
            "Ride created, but the route couldn't be planned right now.",
          );
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
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ride created!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
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
                'Join my RideClub ride "${ride.name}" with code: ${ride.code}',
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
