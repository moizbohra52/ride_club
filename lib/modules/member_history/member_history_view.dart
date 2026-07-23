import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ride_history_entry.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/status_badge.dart';
import 'member_history_controller.dart';

/// Lists every ride a member has been part of (its permanent `rideHistory`).
/// Tapping a row opens that ride's detail screen.
class MemberHistoryView extends GetView<MemberHistoryController> {
  const MemberHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.isMe ? 'My ride history' : '${controller.name}’s rides',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.loading.value) return const _Loading();
          if (controller.history.isEmpty) return _empty(context);
          return StaggerList(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            spacing: 12,
            children: <Widget>[
              for (final RideHistoryEntry e in controller.history)
                _HistoryCard(entry: e),
            ],
          );
        }),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
              child: Icon(
                Icons.history_rounded,
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('No rides yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              controller.isMe
                  ? 'Rides you create or join will show up here.'
                  : '${controller.name} hasn’t joined any rides yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const AppCard(child: SkeletonListTile()),
      ),
    );
  }
}

/// One ride in the member's history — styled like the "My Rides" card but with
/// a status line reflecting whether they left the ride.
class _HistoryCard extends StatelessWidget {
  final RideHistoryEntry entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isHost = entry.isHost;
    return AppCard(
      onTap: () => Get.toNamed(Routes.rideDetail, arguments: entry.rideId),
      accentColor: isHost ? AppColors.surfaceAccent : scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  entry.name.isEmpty ? 'Ride' : entry.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${isHost ? 'Host' : 'Rider'}'
                  '${entry.joinedAt != null ? ' · Joined ${_date(entry.joinedAt!)}' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (entry.hasLeft)
            StatusBadge.label(
              label: 'Left',
              color: scheme.surfaceContainerHighest,
              textColor: scheme.onSurfaceVariant,
            )
          else
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  static String _date(DateTime d) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}
