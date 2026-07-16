import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography scale for RideClub.
///
/// Wraps the Poppins [TextTheme] from [AppTheme] behind intent-based getters so
/// screens stop hard-coding font sizes and stay consistent. Usage:
///
/// ```dart
/// Text('Hello', style: context.tText.title);
/// ```
///
/// The scale mirrors the sizes defined in [AppTheme] (display 32/w800,
/// heading 17/w700, body 14/w400, label 13/w600, caption 11/w500).
class AppTypography {
  const AppTypography();

  // ── Display / hero ────────────────────────────────────────────────────────
  static TextStyle display(BuildContext context) => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: Theme.of(context).colorScheme.onSurface,
  );

  // ── Title Large (card hero titles, e.g. ride name) ────────────────────────
  static TextStyle titleLarge(BuildContext context) => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
    color: Theme.of(context).colorScheme.onSurface,
  );

  // ── Title (screen headers, card titles) ───────────────────────────────────
  static TextStyle title(BuildContext context) => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: Theme.of(context).colorScheme.onSurface,
  );

  // ── Heading (section labels, list titles) ─────────────────────────────────
  static TextStyle heading(BuildContext context) => GoogleFonts.poppins(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: Theme.of(context).colorScheme.onSurface,
  );

  // ── Body (default paragraph text) ─────────────────────────────────────────
  static TextStyle body(BuildContext context) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  // ── Body Strong (emphasized inline text on surface) ───────────────────────
  static TextStyle bodyStrong(BuildContext context) => body(context).copyWith(
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );

  // ── Label (buttons, chips, emphasis) ──────────────────────────────────────
  static TextStyle label(BuildContext context) => GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );

  // ── Caption (metadata, hints, uppercase tags) ─────────────────────────────
  static TextStyle caption(BuildContext context) => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// Ergonomic access to the type scale, e.g. `context.tText.body`.
///
/// [AppTypography]'s styles are static methods taking a [BuildContext]; this
/// extension binds `this` context so call sites read cleanly without repeating
/// `AppTypography.x(context)`.
extension AppTypographyX on BuildContext {
  BoundTypography get tText => BoundTypography(this);
}

/// Context-bound view over [AppTypography] returned by [AppTypographyX.tText].
class BoundTypography {
  final BuildContext _c;
  const BoundTypography(this._c);

  TextStyle get display => AppTypography.display(_c);
  TextStyle get titleLarge => AppTypography.titleLarge(_c);
  TextStyle get title => AppTypography.title(_c);
  TextStyle get heading => AppTypography.heading(_c);
  TextStyle get body => AppTypography.body(_c);
  TextStyle get bodyStrong => AppTypography.bodyStrong(_c);
  TextStyle get label => AppTypography.label(_c);
  TextStyle get caption => AppTypography.caption(_c);
}
