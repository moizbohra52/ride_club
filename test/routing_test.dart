import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_club/core/utils/polyline_codec.dart';
import 'package:ride_club/models/route_result.dart';
import 'package:ride_club/services/routing_service.dart';

void main() {
  test('decodePolyline decodes the canonical Google sample', () {
    final List<List<double>> pts =
        decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0][0], closeTo(38.5, 0.01));
    expect(pts[0][1], closeTo(-120.2, 0.01));
    expect(pts[2][0], closeTo(43.252, 0.01));
    expect(pts[2][1], closeTo(-126.453, 0.01));
  });

  test('RouteResult formatting km / minutes', () {
    const RouteResult r = RouteResult(
      points: <LatLng>[LatLng(0, 0)],
      distanceMeters: 42300,
      durationSeconds: 3300,
    );
    expect(r.distanceText, '42.3 km');
    expect(r.etaText, '55 min');
  });

  test('RouteResult formatting metres / hours', () {
    const RouteResult short = RouteResult(
      points: <LatLng>[LatLng(0, 0)],
      distanceMeters: 850,
      durationSeconds: 3900,
    );
    expect(short.distanceText, '850 m');
    expect(short.etaText, '1 h 5 min');
  });

  test('RoutingService parses OSRM response + sends User-Agent', () async {
    final MockClient mock = MockClient((http.Request req) async {
      expect(req.headers['User-Agent'], isNotEmpty);
      return http.Response(
        '{"code":"Ok","routes":[{"distance":42300.0,"duration":3300.0,'
        '"geometry":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"}]}',
        200,
      );
    });
    final RoutingService svc = RoutingService();
    final RouteResult? r = await svc.route(
      const LatLng(38.5, -120.2),
      const LatLng(43.2, -126.4),
      client: mock,
    );
    expect(r, isNotNull);
    expect(r!.distanceMeters, 42300.0);
    expect(r.points.length, 3);
  });
}
