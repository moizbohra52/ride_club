import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_elevation.dart';

/// A full-width filled button that shows a spinner while [loading] and disables
/// itself. Standardizes the primary CTA across auth/profile screens.
///
/// Features a subtle gradient background and press-scale animation for a
/// premium tactile feel.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool useGradient;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.useGradient = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.loading || widget.onPressed == null;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (widget.useGradient) {
      return AnimatedBuilder(
        animation: _scaleAnim,
        builder: (BuildContext context, Widget? child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          );
        },
        child: GestureDetector(
          onTapDown: disabled ? null : (_) => _scaleCtrl.forward(),
          onTapUp: disabled
              ? null
              : (_) {
                  _scaleCtrl.reverse();
                  widget.onPressed?.call();
                },
          onTapCancel: disabled ? null : () => _scaleCtrl.reverse(),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: disabled
                  ? null
                  : const LinearGradient(
                      colors: AppColors.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: disabled ? scheme.onSurface.withValues(alpha: 0.12) : null,
              borderRadius: AppRadius.lgRadius,
              boxShadow: disabled
                  ? null
                  : AppElevation.medium(AppColors.seed),
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          Icon(widget.icon, size: 22, color: Colors.white),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    // Standard FilledButton with scale animation.
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => _scaleCtrl.forward(),
        onTapUp: disabled ? null : (_) => _scaleCtrl.reverse(),
        onTapCancel: disabled ? null : () => _scaleCtrl.reverse(),
        child: Container(
          decoration: disabled
              ? null
              : BoxDecoration(
                  borderRadius: AppRadius.lgRadius,
                  boxShadow: AppElevation.soft(AppColors.seed),
                ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
            ),
            onPressed: disabled ? null : widget.onPressed,
            child: widget.loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (widget.icon != null) ...<Widget>[
                        Icon(widget.icon, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
