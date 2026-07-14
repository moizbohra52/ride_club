import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ride_club/services/geo_service.dart';

void main() {
  test('searchPlaces parses Nominatim array + sends User-Agent', () async {
    final MockClient mock = MockClient((http.Request req) async {
      expect(req.headers['User-Agent'], isNotEmpty);
      return http.Response(
          '[{"lat":"30.12","lon":"78.45","display_name":"Rishikesh"}]', 200);
    });
    final GeoService svc = GeoService();
    final res = await svc.searchPlaces('Rishikesh', client: mock);
    expect(res, hasLength(1));
    expect(res.first.displayName, 'Rishikesh');
    expect(res.first.lat, closeTo(30.12, 0.001));
  });

  test('searchPlaces returns empty for short query', () async {
    final GeoService svc = GeoService();
    expect(await svc.searchPlaces('ab'), isEmpty);
  });
}
