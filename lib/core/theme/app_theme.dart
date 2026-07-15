import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';

/// Material 3 light & dark themes for RideClub.
///
/// Both themes are generated from a single [AppColors.seed] so the palette stays
/// consistent, then customized for inputs, cards, buttons, and app bars.
/// Uses Google Fonts (Poppins) for a modern, premium feel.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final bool isDark = brightness == Brightness.dark;

    final TextTheme baseText = GoogleFonts.poppinsTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: baseText.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        labelSmall: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : AppColors.primaryGlow.withValues(alpha: 0.15),
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.lgRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgRadius,
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgRadius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: GoogleFonts.poppins(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIconColor: WidgetStateColor.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.focused)
              ? scheme.primary
              : scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        suffixIconColor: WidgetStateColor.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.focused)
              ? scheme.primary
              : scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        indicatorColor: scheme.primaryContainer,
        backgroundColor: isDark
            ? scheme.surface
            : scheme.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            );
          }
          return GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          // Matches AppRadius.xl (24) — asymmetric radius has no direct getter.
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlRadius,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smRadius,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smRadius,
        ),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdRadius,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
    );
  }
}
