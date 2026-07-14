import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/member_location.dart';
import '../../models/ride_member.dart';
import '../../models/route_result.dart';
import '../../routes/app_routes.dart';
import '../../widgets/status_badge.dart';

/// Shows a bottom sheet with a member's profile info, and — when [live] is
/// provided (i.e. the Live Map screen is open and has RTDB data for this
/// member) — their live status: online/offline, speed, battery, and ETA to
/// destination if [route] is given.
///
/// When [live] is null (e.g. opened from Ride Detail, which has no RTDB
/// access), shows a prompt to open the live map instead.
void showMemberDetail(
  BuildContext context, {
  required RideMember member,
  required String rideId,
  MemberLocation? live,
  RouteResult? route,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;

  Get.bottomSheet(
    SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: member.color.withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: member.color.withValues(alpha: 0.15),
                    backgroundImage: member.photoUrl != null
                        ? CachedNetworkImageProvider(member.photoUrl!)
                        : null,
                    child: member.photoUrl == null
                        ? Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: member.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        member.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          if (member.isHost) ...<Widget>[
                            StatusBadge.label(
                              label: 'Host',
                              color: scheme.primaryContainer,
                              textColor: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (member.joinedAt != null)
                            Expanded(
                              child: Text(
                                'Joined ${_formatDate(member.joinedAt!)}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            if (live != null)
              _LiveStatus(live: live, route: route)
            else
              _NoLiveData(rideId: rideId),
          ],
        ),
      ),
    ),
    backgroundColor: scheme.surface,
  );
}

String _formatDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _LiveStatus extends StatelessWidget {
  final MemberLocation live;
  final RouteResult? route;
  const _LiveStatus({required this.live, this.route});

  @override
  Widget build(BuildContext context) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _row(context, Icons.circle,
            live.online ? scheme.primary : scheme.onSurfaceVariant,
            live.lastSeenText(now)),
        const SizedBox(height: AppSpacing.sm),
        _row(context, Icons.speed_rounded, scheme.onSurfaceVariant,
            '${live.speedKmh.toStringAsFixed(0)} km/h'),
        const SizedBox(height: AppSpacing.sm),
        _row(context, Icons.battery_std_rounded, scheme.onSurfaceVariant,
            '${live.battery}% battery'),
        if (route != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _row(context, Icons.navigation_rounded, scheme.onSurfaceVariant,
              '${route!.distanceText} · ${route!.etaText} to destination'),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, Color color, String text) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _NoLiveData extends StatelessWidget {
  final String rideId;
  const _NoLiveData({required this.rideId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          "Open the live map to see this rider's location.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Get.back();
            Get.toNamed(Routes.rideMap, arguments: rideId);
          },
          icon: const Icon(Icons.map_rounded),
          label: const Text('Open live map'),
        ),
      ],
    );
  }
}
