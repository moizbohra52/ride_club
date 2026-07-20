import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/place_result.dart';
import '../../models/ride.dart';
import '../../models/route_result.dart';
import '../../services/geo_service.dart';
import '../../services/routing_service.dart';

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

/// Shared stops + route-picking behaviour for both creating a new ride
/// ([CreateRideController]) and editing an existing one ([EditRideController]):
/// origin/waypoints/destination search fields, and the auto-triggered OSRM
/// alternatives fetch that feeds the inline [RoutePickerView].
abstract class StopsRouteController extends GetxController {
  final GeoService _geo = Get.find<GeoService>();
  final RoutingService _routing = Get.find<RoutingService>();

  final StopEditor origin = StopEditor();
  final StopEditor destination = StopEditor();
  final RxList<StopEditor> waypoints = <StopEditor>[].obs;
  bool isDisposed = false;

  /// All alternatives OSRM returned for the current stops, shown inline on
  /// the form's map so the user taps one directly — no separate screen.
  final RxList<RouteResult> routeAlternatives = <RouteResult>[].obs;
  final RxInt selectedRouteIndex = 0.obs;
  final RxBool routing = false.obs;
  int _routeRequestId = 0;

  RouteResult? get selectedRoute => routeAlternatives.isEmpty
      ? null
      : routeAlternatives[selectedRouteIndex.value.clamp(
          0, routeAlternatives.length - 1)];

  void selectRoute(int index) {
    if (index < 0 || index >= routeAlternatives.length) return;
    selectedRouteIndex.value = index;
  }

  void addWaypoint() => waypoints.add(StopEditor());

  void removeWaypoint(int i) {
    if (i < 0 || i >= waypoints.length) return;
    waypoints[i].dispose();
    waypoints.removeAt(i);
    routeAlternatives.clear();
    maybeAutoRoute();
  }

  void reorderWaypoints(int oldIndex, int newIndex) {
    // ReorderableListView convention: adjust when moving down.
    int n = newIndex;
    if (n > oldIndex) n -= 1;
    final StopEditor e = waypoints.removeAt(oldIndex);
    waypoints.insert(n, e);
    routeAlternatives.clear();
    maybeAutoRoute();
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
    routeAlternatives.clear(); // stops changed → old alternatives are stale
    maybeAutoRoute();
  }

  RideDestination? dest(StopEditor e) {
    final PlaceResult? p = e.chosen.value;
    if (p == null) return null;
    return RideDestination(lat: p.lat, lng: p.lng, label: p.displayName);
  }

  List<LatLng> get orderedStopPoints {
    final List<RideDestination> ordered = <RideDestination>[
      ?dest(origin),
      ...waypoints.map(dest).whereType<RideDestination>(),
      ?dest(destination),
    ];
    return ordered.map((RideDestination s) => LatLng(s.lat, s.lng)).toList();
  }

  /// As soon as 2+ stops are chosen, fetch route alternatives and open the
  /// map preview automatically — mirrors Google Maps' "pick stops → routes
  /// appear" flow instead of making the user tap a separate button.
  Future<void> maybeAutoRoute() async {
    final List<LatLng> stops = orderedStopPoints;
    if (stops.length < 2) return;
    await pickRoute(stops);
  }

  /// Fetches every alternative OSRM offers for [stops] and publishes them to
  /// [routeAlternatives] (fastest first, pre-selected) so the form's inline
  /// map can render them as tappable polylines — no separate screen.
  Future<void> pickRoute(List<LatLng> stops) async {
    final int requestId = ++_routeRequestId;
    routing.value = true;
    try {
      final List<RouteResult> alternatives =
          await _routing.routeAlternatives(stops);
      if (isDisposed || requestId != _routeRequestId) return;
      if (alternatives.isEmpty) {
        UiHelpers.warning("Couldn't find a route for these stops.");
        routeAlternatives.clear();
        return;
      }
      routeAlternatives.value = alternatives;
      selectedRouteIndex.value = 0;
    } finally {
      if (!isDisposed && requestId == _routeRequestId) routing.value = false;
    }
  }

  /// Ensures a route is selected before a create/save action proceeds —
  /// fetches one if the auto-trigger never ran. Returns the resolved stops
  /// (origin+waypoints+destination) so callers don't recompute them.
  Future<List<RideDestination>> resolveStopsAndRoute() async {
    final RideDestination? originD = dest(origin);
    final List<RideDestination> waypointDs =
        waypoints.map(dest).whereType<RideDestination>().toList();
    final RideDestination? destD = dest(destination);
    final List<RideDestination> ordered = <RideDestination>[
      ?originD,
      ...waypointDs,
      ?destD,
    ];
    if (ordered.length >= 2 && routeAlternatives.isEmpty) {
      await pickRoute(
        ordered.map((RideDestination s) => LatLng(s.lat, s.lng)).toList(),
      );
    }
    return ordered;
  }

  void disposeStops() {
    isDisposed = true;
    origin.dispose();
    destination.dispose();
    for (final StopEditor e in waypoints) {
      e.dispose();
    }
  }
}
