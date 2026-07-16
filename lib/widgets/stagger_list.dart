import 'package:flutter/material.dart';

/// A [ListView] whose children fade + slide in with a staggered delay, giving
/// list screens a calm, premium entrance. Replaces the per-screen
/// `_AnimatedRideCard` pattern with a single reusable widget.
///
/// Each item animates over [duration] (default 420ms) and starts
/// [stagger] ms after the previous one (default 60ms).
class StaggerList extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final double spacing;
  final Duration duration;
  final int staggerMs;
  final Axis scrollDirection;

  const StaggerList({
    super.key,
    required this.children,
    this.padding,
    this.physics,
    this.spacing = 12,
    this.duration = const Duration(milliseconds: 420),
    this.staggerMs = 60,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<StaggerList> createState() => _StaggerListState();
}

class _StaggerListState extends State<StaggerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final int total = widget.children.length;
    _ctrl = AnimationController(
      vsync: this,
      duration:
          widget.duration + Duration(milliseconds: widget.staggerMs * total),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool vertical = widget.scrollDirection == Axis.vertical;
    final double totalMs = _ctrl.duration?.inMilliseconds.toDouble() ?? 1;
    return ListView.separated(
      scrollDirection: widget.scrollDirection,
      padding: widget.padding,
      physics: widget.physics,
      itemCount: widget.children.length,
      separatorBuilder: (_, _) => SizedBox(
        width: vertical ? 0 : widget.spacing,
        height: widget.spacing,
      ),
      itemBuilder: (BuildContext context, int i) {
        final double start = (widget.staggerMs * i) / totalMs;
        final double end = (start + widget.duration.inMilliseconds / totalMs)
            .clamp(0.0, 1.0);
        final Interval interval = Interval(start, end, curve: Curves.easeOut);
        final Animation<Offset> slide = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _ctrl, curve: interval));
        return FadeTransition(
          opacity: CurvedAnimation(parent: _ctrl, curve: interval),
          child: SlideTransition(position: slide, child: widget.children[i]),
        );
      },
    );
  }
}
