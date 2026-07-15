import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart' hide Response;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../core/utils/polyline_codec.dart';
import '../models/route_result.dart';

/// OSRM driving routes, serialized through one global queue that spaces HTTP
/// requests ≥1.2s apart to respect the public API's fair-use policy. My route
/// plus every member's route all flow through this single chain, so the total
/// request rate stays within limits regardless of group size.
class RoutingService extends GetxService {
  static const Duration _minSpacing = Duration(milliseconds: 1200);
  Future<void> _chain = Future<void>.value();
  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<RouteResult?> route(LatLng from, LatLng to, {http.Client? client}) {
    final Completer<RouteResult?> out = Completer<RouteResult?>();
    _chain = _chain.then((_) async {
      final int sinceMs =
          DateTime.now().difference(_lastCall).inMilliseconds;
      final int waitMs = _minSpacing.inMilliseconds - sinceMs;
      if (waitMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
      _lastCall = DateTime.now();
      out.complete(await _fetch(from, to, client));
    });
    return out.future;
  }

  Future<RouteResult?> routeMulti(List<LatLng> stops,
      {http.Client? client}) {
    if (stops.length < 2) return Future<RouteResult?>.value(null);
    final Completer<RouteResult?> out = Completer<RouteResult?>();
    _chain = _chain.then((_) async {
      final int sinceMs = DateTime.now().difference(_lastCall).inMilliseconds;
      final int waitMs = _minSpacing.inMilliseconds - sinceMs;
      if (waitMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
      _lastCall = DateTime.now();
      out.complete(await _fetchMulti(stops, client));
    });
    return out.future;
  }

  Future<RouteResult?> _fetchMulti(
      List<LatLng> stops, http.Client? client) async {
    final http.Client c = client ?? http.Client();
    try {
      final String coords = stops
          .map((LatLng s) => '${s.longitude},${s.latitude}')
          .join(';');
      final Uri uri = Uri.parse(
        '${AppConstants.osrmBaseUrl}/route/v1/driving/$coords'
        '?overview=full&geometries=polyline&alternatives=false&steps=false',
      );
      final http.Response res = await c
          .get(uri, headers: <String, String>{
            'User-Agent': AppConstants.httpUserAgent,
          })
          .timeout(AppConstants.networkTimeout);
      if (res.statusCode != 200) {
        Log.e('OSRM multi HTTP ${res.statusCode}');
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final List<dynamic> routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      final Map<String, dynamic> r0 = routes.first as Map<String, dynamic>;
      final List<List<double>> pts =
          decodePolyline(r0['geometry'] as String);
      return RouteResult(
        points: pts.map((p) => LatLng(p[0], p[1])).toList(),
        distanceMeters: (r0['distance'] as num).toDouble(),
        durationSeconds: (r0['duration'] as num).toDouble(),
      );
    } catch (e, s) {
      Log.e('OSRM routeMulti failed', error: e, stack: s);
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  Future<RouteResult?> _fetch(
      LatLng from, LatLng to, http.Client? client) async {
    final http.Client c = client ?? http.Client();
    try {
      final String coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final Uri uri = Uri.parse(
        '${AppConstants.osrmBaseUrl}/route/v1/driving/$coords'
        '?overview=full&geometries=polyline&alternatives=false&steps=false',
      );
      final http.Response res = await c
          .get(uri, headers: <String, String>{
            'User-Agent': AppConstants.httpUserAgent,
          })
          .timeout(AppConstants.networkTimeout);
      if (res.statusCode != 200) {
        Log.e('OSRM HTTP ${res.statusCode}');
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final List<dynamic> routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      final Map<String, dynamic> r0 = routes.first as Map<String, dynamic>;
      final List<List<double>> pts =
          decodePolyline(r0['geometry'] as String);
      return RouteResult(
        points: pts.map((p) => LatLng(p[0], p[1])).toList(),
        distanceMeters: (r0['distance'] as num).toDouble(),
        durationSeconds: (r0['duration'] as num).toDouble(),
      );
    } catch (e, s) {
      Log.e('OSRM route failed', error: e, stack: s);
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}
