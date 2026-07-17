import 'package:flutter/material.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_spacing.dart';

/// Shared surface container: rounded corners, a themed border, and a soft
/// dual-layer shadow. Replaces the "surface + border + shadow" Container
/// pattern that was copy-pasted across ride cards and list tiles.
///
/// Pass [accentColor] to render a 4px left accent strip (e.g. to mark the
/// host's ride card). Pass [onTap] to make the whole card tappable with an
/// ink ripple; omit it for a static card.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (accentColor != null)
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );

    final Decoration decoration = BoxDecoration(
      color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
      borderRadius: AppRadius.lgRadius,
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
      ),
      boxShadow: AppElevation.soft(isDark ? Colors.black : scheme.primary),
    );

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Ink(decoration: decoration, child: content),
      ),
    );
  }
}
