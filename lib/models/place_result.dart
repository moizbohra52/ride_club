/// A place candidate returned by Nominatim search. `lat`/`lon` arrive as
/// strings in the JSON, so we parse them to doubles.
class PlaceResult {
  final double lat;
  final double lng;
  final String displayName;

  const PlaceResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> j) => PlaceResult(
        lat: double.parse(j['lat'].toString()),
        lng: double.parse(j['lon'].toString()),
        displayName: (j['display_name'] ?? '') as String,
      );
}
