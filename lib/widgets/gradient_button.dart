import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_typography.dart';

/// The app's primary call-to-action: a full-width gradient button with the
/// brand glow shadow and a light haptic on tap. Standardizes the gradient CTA
/// that was previously rebuilt inline on login, ride detail, and the map's
/// "Start" button.
///
/// Pass [gradient]/[glowTint] to use the sunset accent instead of the brand
/// blue for a special CTA.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final List<Color> gradient;
  final Color glowTint;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.gradient = AppColors.brandGradient,
    this.glowTint = AppColors.seed,
    this.height = 54,
  });

  /// Sunset-accent variant for the one special CTA per screen.
  const GradientButton.accent({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.height = 54,
  }) : gradient = AppColors.accentGradient,
       glowTint = AppColors.sunset;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdRadius,
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: enabled ? AppElevation.medium(glowTint) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.mdRadius,
            onTap: enabled
                ? () {
                    HapticFeedback.mediumImpact();
                    onTap!();
                  }
                : null,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: AppTypography.label(
                      context,
                    ).copyWith(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
