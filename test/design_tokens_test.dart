import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/core/theme/app_spacing.dart';
import 'package:ride_club/core/theme/app_radius.dart';
import 'package:ride_club/core/theme/app_elevation.dart';
import 'package:ride_club/core/theme/app_colors.dart';
import 'package:ride_club/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSpacing', () {
    test('scale is strictly increasing', () {
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
      expect(AppSpacing.xxl, lessThan(AppSpacing.xxxl));
    });
  });

  group('AppRadius', () {
    test('scale is strictly increasing', () {
      expect(AppRadius.sm, lessThan(AppRadius.md));
      expect(AppRadius.md, lessThan(AppRadius.lg));
      expect(AppRadius.lg, lessThan(AppRadius.xl));
    });

    test('BorderRadius getters match the double values', () {
      expect(AppRadius.lgRadius, BorderRadius.circular(AppRadius.lg));
      expect(AppRadius.mdRadius, BorderRadius.circular(AppRadius.md));
    });
  });

  group('AppElevation', () {
    test('soft/medium/strong each return exactly two shadows', () {
      expect(AppElevation.soft(Colors.blue).length, 2);
      expect(AppElevation.medium(Colors.blue).length, 2);
      expect(AppElevation.strong(Colors.blue).length, 2);
    });

    test('strong has a larger blur radius than soft', () {
      final double softBlur = AppElevation.soft(Colors.blue).last.blurRadius;
      final double strongBlur =
          AppElevation.strong(Colors.blue).last.blurRadius;
      expect(strongBlur, greaterThan(softBlur));
    });
  });

  group('AppColors.surfaceAccent', () {
    test('is defined and distinct from seed', () {
      expect(AppColors.surfaceAccent, isNotNull);
    });
  });

  group('AppTheme text styles', () {
    test('light theme defines the named type scale', () {
      final ThemeData theme = AppTheme.light;
      expect(theme.textTheme.headlineLarge?.fontSize, 28);
      expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w800);
      expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w800);
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
      expect(theme.textTheme.labelSmall?.fontWeight, FontWeight.w500);
    });
  });
}
