import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

/// A translucent, blurred "glass" surface used for overlays floating above the
/// map (info card, members bar, SOS banner). Reads as a floating pane while
/// letting the map show through softly.
///
/// Uses [ClipRRect] + [BackdropFilter] for the blur. The tint switches between
/// [AppColors.glassLight] and [AppColors.glassDark] based on the active theme.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double elevation;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.borderRadius,
    this.blur = 12,
    this.elevation = 6,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color tint = isDark ? AppColors.glassDark : AppColors.glassLight;
    final BorderRadius radius = borderRadius ?? AppRadius.lgRadius;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget surface = Material(
      elevation: elevation,
      shadowColor: AppColors.primaryGlow.withValues(alpha: 0.15),
      borderRadius: radius,
      color: tint,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ColorFilter.matrix(<double>[
            1, 0, 0, 0, 0, //
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 0.12, 0, // subtle contrast lift
          ]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.3 : 0.15,
                ),
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: surface),
    );
  }
}
