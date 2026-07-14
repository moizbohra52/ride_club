import 'dart:convert';
import 'package:get/get.dart' hide Response;
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../models/place_result.dart';

/// Nominatim geocoding search. Sends the OSM-required User-Agent and returns
/// place candidates for a free-text query. Callers debounce input to respect
/// OSM's usage policy (≤1 request/sec).
class GeoService extends GetxService {
  Future<List<PlaceResult>> searchPlaces(String query,
      {http.Client? client}) async {
    final String q = query.trim();
    if (q.length < 3) return <PlaceResult>[];
    final http.Client c = client ?? http.Client();
    try {
      final Uri uri =
          Uri.parse('${AppConstants.nominatimBaseUrl}/search').replace(
        queryParameters: <String, String>{
          'q': q,
          'format': 'json',
          'limit': '6',
          'addressdetails': '0',
        },
      );
      final http.Response res = await c
          .get(uri, headers: <String, String>{
            'User-Agent': AppConstants.httpUserAgent,
          })
          .timeout(AppConstants.networkTimeout);
      if (res.statusCode != 200) return <PlaceResult>[];
      final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((dynamic e) => PlaceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      Log.e('Nominatim search failed', error: e, stack: s);
      return <PlaceResult>[];
    } finally {
      if (client == null) c.close();
    }
  }
}
