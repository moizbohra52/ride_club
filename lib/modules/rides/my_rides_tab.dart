import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/ride.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
import 'rides_shell_controller.dart';

class MyRidesTab extends StatelessWidget {
  const MyRidesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final RidesShellController c = Get.find<RidesShellController>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? uid = Get.find<AuthService>().uid;
    return Obx(() {
      if (c.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (c.myRides.isEmpty) return _empty(context, scheme);
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: c.myRides.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, int i) {
          final Ride r = c.myRides[i];
          final bool host = uid != null && r.isHost(uid);
          return _AnimatedRideCard(
            index: i,
            child: _RideCard(ride: r, isHost: host),
          );
        },
      );
    });
  }

  Widget _empty(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.route_rounded,
                  size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text('No rides yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Create a ride or join one with a code to get started.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Staggered fade+slide animation for each card in the list.
class _AnimatedRideCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedRideCard({required this.index, required this.child});

  @override
  State<_AnimatedRideCard> createState() => _AnimatedRideCardState();
}

class _AnimatedRideCardState extends State<_AnimatedRideCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger based on index.
    Future<void>.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Ride ride;
  final bool isHost;
  const _RideCard({required this.ride, required this.isHost});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => Get.toNamed(Routes.rideDetail, arguments: ride.id),
      accentColor: isHost ? AppColors.surfaceAccent : scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md + 2),
      child: Row(
        children: <Widget>[
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: isHost ? AppColors.surfaceAccent : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isHost ? Icons.star_rounded : Icons.group_rounded,
              color: isHost ? Colors.white : scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ride.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${isHost ? 'Host' : 'Rider'} · Code ${ride.code}'
                  '${ride.isActive ? '' : ' · Ended'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: Get.find<ChatService>().unreadCount(ride.id),
            builder: (_, AsyncSnapshot<int> snap) {
              final int n = snap.data ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: StatusBadge.count(count: n),
              );
            },
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
