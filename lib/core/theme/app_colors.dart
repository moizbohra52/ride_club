import 'package:flutter/material.dart';

/// Central color palette for RideClub.
///
/// [seed] drives the Material 3 [ColorScheme] for both light and dark themes.
/// [memberColors] are assigned round-robin to ride members so each rider gets a
/// distinct, high-contrast marker on the map (used from Phase 3 onward).
class AppColors {
  AppColors._();

  /// Brand seed — a confident travel-blue ("sky").
  static const Color seed = Color(0xFF2563EB);

  /// Deep midnight blue — the "night ride" ink, used for strong text on light.
  static const Color ink = Color(0xFF0F1B2D);

  /// Warm sunset orange — the adventure accent. Used sparingly for the one
  /// element that should pop (primary CTA glow, active markers).
  static const Color sunset = Color(0xFFF97316);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  /// SOS button color — deliberately the most saturated red in the app.
  static const Color sos = Color(0xFFE11D48);

  /// Tonal accent for headers/badges that previously duplicated
  /// [brandGradient] purely for emphasis (profile header, avatar badge, host
  /// markers). Solid, not a gradient — reserves the gradient for the two
  /// true hero moments (login hero, ride-code card).
  static const Color surfaceAccent = Color(0xFF3B5DE0);

  // ── Gradient pairs ────────────────────────────────────────────────────────

  /// Primary brand gradient (hero backgrounds, CTA buttons).
  static const List<Color> brandGradient = <Color>[
    Color(0xFF1D4ED8), // deeper blue
    Color(0xFF3B82F6), // lighter sky blue
  ];

  /// Sunset accent gradient (special CTAs, highlights).
  static const List<Color> accentGradient = <Color>[
    Color(0xFFEA580C), // warm orange
    Color(0xFFF97316), // bright sunset
  ];

  /// Midnight gradient for dark splash / hero areas.
  static const List<Color> midnightGradient = <Color>[
    Color(0xFF0F172A), // near-black slate
    Color(0xFF1E3A5F), // deep ocean blue
  ];

  // ── Surface tints ─────────────────────────────────────────────────────────

  /// Subtle blue tint for light-mode card backgrounds.
  static const Color surfaceTintLight = Color(0xFFF0F5FF);

  /// Subtle blue tint for dark-mode card backgrounds.
  static const Color surfaceTintDark = Color(0xFF1A2332);

  // ── Glow / shimmer ────────────────────────────────────────────────────────

  /// Soft glow for primary CTA shadows.
  static const Color primaryGlow = Color(0x402563EB);

  /// Soft glow for sunset accent shadows.
  static const Color accentGlow = Color(0x40F97316);

  /// Muted on-surface tone (≈60% onSurfaceVariant) for secondary/metadata text.
  /// Use instead of hand-tuned `withValues(alpha: 0.5)` so the same muted
  /// contrast is applied consistently across light & dark themes.
  static const Color onSurfaceMuted = Color(0x991F2937);

  /// Translucent surface tint used for glass/blur overlays floating above the
  /// map (info card, members bar, SOS banner).
  static const Color glassLight = Color(0xF2FFFFFF);
  static const Color glassDark = Color(0xF21A2332);

  /// Distinct marker colors for ride members. 10 visually separable hues.
  static const List<Color> memberColors = <Color>[
    Color(0xFF2563EB), // blue
    Color(0xFFDC2626), // red
    Color(0xFF16A34A), // green
    Color(0xFF9333EA), // purple
    Color(0xFFEA580C), // orange
    Color(0xFF0891B2), // cyan
    Color(0xFFDB2777), // pink
    Color(0xFF65A30D), // lime
    Color(0xFF7C3AED), // violet
    Color(0xFF0D9488), // teal
  ];

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
