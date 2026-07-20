import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/place_result.dart';
import '../../models/ride.dart';
import '../../models/route_result.dart';
import '../../services/ride_service.dart';
import 'stops_route_controller.dart';

class EditRideController extends StopsRouteController {
  final RideService _rides = Get.find<RideService>();
  final Ride ride;
  EditRideController(this.ride);

  late final TextEditingController nameField =
      TextEditingController(text: ride.name);
  final RxBool saving = false.obs;

  @override
  void onInit() {
    super.onInit();
    _prefill(origin, ride.origin);
    for (final RideDestination w in ride.waypoints) {
      final StopEditor e = StopEditor();
      _prefill(e, w);
      waypoints.add(e);
    }
    _prefill(destination, ride.destination);
    if (ride.plannedRoute != null && ride.plannedRoute!.isNotEmpty) {
      routeAlternatives.value = <RouteResult>[
        RouteResult(
          points: ride.plannedRoute!,
          distanceMeters: ride.plannedDistanceMeters ?? 0,
          durationSeconds: ride.plannedDurationSeconds ?? 0,
        ),
      ];
      selectedRouteIndex.value = 0;
    }
  }

  void _prefill(StopEditor e, RideDestination? d) {
    if (d == null) return;
    final PlaceResult p = PlaceResult(lat: d.lat, lng: d.lng, displayName: d.label);
    e.chosen.value = p;
    e.field.text = p.displayName;
  }

  Future<void> save() async {
    if (nameField.text.trim().isEmpty) {
      UiHelpers.error('Give your ride a name.');
      return;
    }
    saving.value = true;
    try {
      final RideDestination? originD = dest(origin);
      final List<RideDestination> waypointDs =
          waypoints.map(dest).whereType<RideDestination>().toList();
      final RideDestination? destD = dest(destination);
      final List<RideDestination> ordered = await resolveStopsAndRoute();

      final RouteResult? r = ordered.length >= 2 ? selectedRoute : null;
      await _rides.updateRide(
        rideId: ride.id,
        name: nameField.text,
        origin: originD,
        waypoints: waypointDs,
        destination: destD,
        plannedRoute: r?.points,
        plannedDistanceMeters: r?.distanceMeters,
        plannedDurationSeconds: r?.durationSeconds,
      );
      UiHelpers.success('Ride updated.');
      if (!isDisposed) Get.back();
    } catch (e) {
      UiHelpers.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    disposeStops();
    nameField.dispose();
    super.onClose();
  }
}
