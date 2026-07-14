import 'package:latlong2/latlong.dart';

/// A driving route from OSRM: the polyline points plus total distance and
/// duration.
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;

  String get distanceText => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${distanceKm.toStringAsFixed(1)} km';

  String get etaText {
    final int mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final int h = mins ~/ 60;
    final int m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}
