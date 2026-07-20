import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/ride.dart';
import '../../models/route_result.dart';
import '../../services/ride_service.dart';
import 'rides_shell_controller.dart';
import 'stops_route_controller.dart';

export 'stops_route_controller.dart' show StopEditor;

class CreateRideController extends StopsRouteController {
  final RideService _rides = Get.find<RideService>();

  final TextEditingController nameField = TextEditingController();
  final RxBool creating = false.obs;

  Future<void> create() async {
    if (nameField.text.trim().isEmpty) {
      UiHelpers.error('Give your ride a name.');
      return;
    }
    creating.value = true;
    try {
      final RideDestination? originD = dest(origin);
      final List<RideDestination> waypointDs =
          waypoints.map(dest).whereType<RideDestination>().toList();
      final RideDestination? destD = dest(destination);
      final List<RideDestination> ordered = await resolveStopsAndRoute();

      // TEMP DIAGNOSTIC (remove after debugging): what stops are chosen?
      Log.d(
        'create(): origin=${origin.chosen.value?.displayName} '
        'waypoints=${waypoints.length}(chosen ${waypointDs.length}) '
        'dest=${destination.chosen.value?.displayName} '
        'ordered=${ordered.length}',
      );

      double? plannedDist;
      double? plannedDur;
      if (ordered.length >= 2) {
        final RouteResult? r = selectedRoute;
        if (r == null) {
          UiHelpers.warning(
            "Ride created, but the route couldn't be planned right now.",
          );
        } else {
          plannedDist = r.distanceMeters;
          plannedDur = r.durationSeconds;
        }
      }

      final Ride ride = await _rides.createRide(
        name: nameField.text,
        origin: originD,
        waypoints: waypointDs,
        destination: destD,
        plannedRoute: selectedRoute?.points,
        plannedDistanceMeters: plannedDist,
        plannedDurationSeconds: plannedDur,
      );
      _showCreated(ride);
      if (!isDisposed) {
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
        routeAlternatives.clear();
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
    disposeStops();
    nameField.dispose();
    super.onClose();
  }
}
