/// App-wide constants: identity strings, external service endpoints, timings.
///
/// OSM/Nominatim policy requires a descriptive User-Agent identifying the app
/// and a contact. Update [contactEmail] to a real address before release.
class AppConstants {
  AppConstants._();

  static const String appName = 'RideTogether';

  /// Package name reported to OSM tile servers (flutter_map policy).
  static const String userAgentPackageName = 'com.ridetogether.app';

  /// Contact for Nominatim/Overpass User-Agent (OSM usage policy).
  static const String contactEmail = 'support@ridetogether.app';

  /// Full User-Agent string for Nominatim/Overpass HTTP requests.
  static const String httpUserAgent =
      '$appName/1.0 ($contactEmail)';

  // --- Map / tiles (used from Phase 3) ---
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// CARTO dark-matter raster tiles (OSM-based) for dark theme. Requires
  /// CARTO + OSM attribution (shown in the map's attribution widget).
  static const String osmTileUrlDark =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  // --- Routing (Phase 4) ---
  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  // --- Geocoding / search (Phase 2/8) ---
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  // --- POI (Phase 8) ---
  static const String overpassBaseUrl =
      'https://overpass-api.de/api/interpreter';

  // --- Timings ---
  static const Duration splashMinDuration = Duration(milliseconds: 900);
  static const int otpResendSeconds = 60;
  static const int otpCodeLength = 6;
  static const Duration otpAutoRetrievalTimeout = Duration(seconds: 60);
  static const Duration networkTimeout = Duration(seconds: 20);

  // --- Ride codes (Phase 2) ---
  static const int rideCodeLength = 6;

  /// Deep link base used for shareable ride invites (Phase 2).
  static const String inviteLinkBase = 'https://ridetogether.app/join';

  // --- GetStorage keys ---
  static const String kThemeMode = 'theme_mode';
  static const String kOnboardingDone = 'onboarding_done';
}
