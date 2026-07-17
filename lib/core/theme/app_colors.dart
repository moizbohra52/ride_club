import 'package:flutter/material.dart';

/// Central color palette for RideClub.
///
/// [seed] drives the Material 3 [ColorScheme] for both light and dark themes.
/// [memberColors] are assigned round-robin to ride members so each rider gets a
/// distinct, high-contrast marker on the map (used from Phase 3 onward).
///
/// The palette is a warm coral/salmon system: a single confident coral accent
/// on soft near-white surfaces, matching the app's light, friendly identity.
class AppColors {
  AppColors._();

  /// Brand seed — a warm coral ("salmon"). The one accent that carries the app.
  static const Color seed = Color(0xFFEE8B7B);

  /// Deeper coral — pressed states / gradient end / strong accents.
  static const Color coralDark = Color(0xFFE5735F);

  /// Soft coral — subtle fills, tints, disabled accents.
  static const Color coralSoft = Color(0xFFF6B3A6);

  /// Near-black warm ink — strong text on light surfaces.
  static const Color ink = Color(0xFF2E2E3A);

  /// Warm sunset accent kept as a secondary highlight (rarely used now that
  /// coral is the hero — retained so existing `.accent` call-sites still work).
  static const Color sunset = Color(0xFFF6A560);

  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFE5484D);

  /// SOS button color — the most saturated red in the app.
  static const Color sos = Color(0xFFE63950);

  /// Tonal accent for headers/badges — a solid coral, not a gradient, so the
  /// gradient stays reserved for true hero moments.
  static const Color surfaceAccent = Color(0xFFEE8B7B);

  // ── Gradient pairs ────────────────────────────────────────────────────────

  /// Primary brand gradient (hero backgrounds, CTA buttons) — coral shades.
  static const List<Color> brandGradient = <Color>[
    Color(0xFFF19A88), // light coral
    Color(0xFFE5735F), // deeper coral
  ];

  /// Sunset accent gradient (special CTAs, highlights).
  static const List<Color> accentGradient = <Color>[
    Color(0xFFF6A560), // warm apricot
    Color(0xFFEE8B7B), // coral
  ];

  /// Warm dark gradient for dark splash / hero areas.
  static const List<Color> midnightGradient = <Color>[
    Color(0xFF2A2530), // warm near-black
    Color(0xFF4A3A3A), // deep warm brown-grey
  ];

  // ── Surface tints ─────────────────────────────────────────────────────────

  /// Subtle warm tint for light-mode card backgrounds.
  static const Color surfaceTintLight = Color(0xFFFFF6F4);

  /// Subtle warm tint for dark-mode card backgrounds.
  static const Color surfaceTintDark = Color(0xFF2A2224);

  // ── Glow / shimmer ────────────────────────────────────────────────────────

  /// Soft glow for primary CTA shadows (coral, ~25% alpha).
  static const Color primaryGlow = Color(0x40EE8B7B);

  /// Soft glow for sunset accent shadows.
  static const Color accentGlow = Color(0x40F6A560);

  /// Muted on-surface tone (≈60%) for secondary/metadata text. Use instead of
  /// hand-tuned `withValues(alpha: 0.5)` so the same muted contrast is applied
  /// consistently across light & dark themes.
  static const Color onSurfaceMuted = Color(0x992E2E3A);

  /// Translucent surface tint used for glass/blur overlays floating above the
  /// map (info card, members bar, SOS banner).
  static const Color glassLight = Color(0xF2FFFFFF);
  static const Color glassDark = Color(0xF22A2224);

  // ── Route line colors (live map polylines) ─────────────────────────────────

  /// Route line color for the current user's own path — a decent, dark warm
  /// slate that reads clearly on both light and dark tiles without glowing.
  static const Color routeLine = Color(0xFF5A3E38);

  /// Casing/outline drawn under [routeLine] (and member route lines).
  static const Color routeCasing = Color(0xFFFFFFFF);

  /// Distinct marker colors for ride members. 10 visually separable hues, tuned
  /// to sit harmoniously alongside the coral brand.
  static const List<Color> memberColors = <Color>[
    Color(0xFFEE8B7B), // coral (brand)
    Color(0xFF4E9DE0), // sky blue
    Color(0xFF34C759), // green
    Color(0xFF9B6DDB), // purple
    Color(0xFFF6A560), // apricot
    Color(0xFF17A2A2), // teal
    Color(0xFFE86AA6), // pink
    Color(0xFF8FB93E), // lime
    Color(0xFF6C7BE0), // indigo
    Color(0xFFD9534F), // brick red
  ];

  /// Darkened, muted variants of [memberColors] for polylines — same hue
  /// identity as each member's marker, but toned down so lines stay dark and
  /// never glow.
  static const List<Color> memberRouteColors = <Color>[
    Color(0xFFB5503E), // coral
    Color(0xFF2C5F8A), // blue
    Color(0xFF1E7A38), // green
    Color(0xFF5B3E8A), // purple
    Color(0xFFB56A25), // apricot
    Color(0xFF0F6060), // teal
    Color(0xFF9B3B68), // pink
    Color(0xFF556E1F), // lime
    Color(0xFF3D479B), // indigo
    Color(0xFF8A2F2C), // brick red
  ];

  /// Darkened, muted route-line color for a member key (matches
  /// [memberColorForKey] hue selection).
  static Color memberRouteColorForKey(String key) {
    if (key.isEmpty) return memberRouteColors.first;
    final int hash = key.codeUnits.fold(0, (int acc, int c) => acc + c);
    return memberRouteColors[hash % memberRouteColors.length];
  }

  /// Deterministically pick a member color from an index (e.g. join order).
  static Color memberColorAt(int index) =>
      memberColors[index % memberColors.length];

  /// Deterministically pick a member color from an arbitrary string key
  /// (e.g. a uid) so the same user always gets the same color.
  static Color memberColorForKey(String key) {
    if (key.isEmpty) return memberColors.first;
    final int hash = key.codeUnits.fold(0, (int acc, int c) => acc + c);
    return memberColors[hash % memberColors.length];
  }
}
