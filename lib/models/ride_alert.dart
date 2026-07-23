import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Kind of a transient in-app map alert. Drives its icon + accent color.
enum RideAlertType {
  overtake,
  offline,
  offRoute,
  arrived,
  status, // periodic per-member status digest
}

/// A short-lived notification shown as a slide-in card over the live map (not
/// an OS notification). Raised by [RideMapController] on ride events and on a
/// periodic status tick, then auto-dismissed by the overlay after a few seconds.
class RideAlert {
  /// Monotonic id so the overlay can key/animate each card and dedupe.
  final int id;
  final RideAlertType type;
  final String title;
  final String message;

  const RideAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
  });

  IconData get icon => switch (type) {
        RideAlertType.overtake => Icons.double_arrow_rounded,
        RideAlertType.offline => Icons.cloud_off_rounded,
        RideAlertType.offRoute => Icons.alt_route_rounded,
        RideAlertType.arrived => Icons.flag_rounded,
        RideAlertType.status => Icons.insights_rounded,
      };

  Color get color => switch (type) {
        RideAlertType.overtake => AppColors.seed,
        RideAlertType.offline => AppColors.warning,
        RideAlertType.offRoute => AppColors.danger,
        RideAlertType.arrived => AppColors.success,
        RideAlertType.status => AppColors.seed,
      };

  /// How long the card stays before auto-dismiss. Status digests linger a touch
  /// longer since they carry more to read.
  Duration get ttl => type == RideAlertType.status
      ? const Duration(seconds: 6)
      : const Duration(seconds: 4);
}
