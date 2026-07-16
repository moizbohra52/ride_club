import 'package:flutter/material.dart';

import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';

/// A single shimmer placeholder block that pulses opacity. Package-free — one
/// [AnimationController] drives all descendants via an inherited ticker, so a
/// list of skeletons animates in sync without N controllers.
///
/// Wrap a group in [SkeletonScope]; individual blocks are [SkeletonBox].
class SkeletonScope extends StatefulWidget {
  final Widget child;
  const SkeletonScope({required this.child, super.key});

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonTick(listenable: _controller, child: widget.child);
}

/// Inherited holder so [SkeletonBox] finds the shared pulse animation.
class _SkeletonTick extends InheritedWidget {
  final Listenable listenable;
  const _SkeletonTick({required this.listenable, required super.child});

  static Listenable of(BuildContext context) {
    final _SkeletonTick? t = context
        .dependOnInheritedWidgetOfExactType<_SkeletonTick>();
    assert(t != null, 'SkeletonBox must be inside a SkeletonScope');
    return t!.listenable;
  }

  @override
  bool updateShouldNotify(_SkeletonTick old) => listenable != old.listenable;
}

/// A grey rounded block that pulses. Sizes default to a text-line shape.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? radius;
  final bool circle;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Listenable pulse = _SkeletonTick.of(context);
    final Color base = scheme.onSurface.withValues(alpha: 0.08);
    final Color hi = scheme.onSurface.withValues(alpha: 0.16);
    return AnimatedBuilder(
      animation: pulse,
      builder: (BuildContext context, _) {
        final double t = (pulse as Animation<double>).value;
        return Container(
          width: circle ? height : width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(base, hi, t),
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : (radius ?? AppRadius.smRadius),
          ),
        );
      },
    );
  }
}

/// A ready-made skeleton row matching a list card (avatar + two text lines +
/// chevron). Handy default for list-loading states.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          const SkeletonBox(height: 48, circle: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBox(width: 160, height: 16),
                const SizedBox(height: AppSpacing.sm),
                SkeletonBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
