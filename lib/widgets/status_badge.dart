import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

/// Small pill/circle used for counts (chat unread) and short tags
/// ("Host", "Ended"). Unifies three hand-rolled variants that previously
/// existed in my_rides_tab.dart and ride_detail_view.dart.
class StatusBadge extends StatelessWidget {
  final int? count;
  final String? label;
  final Color color;
  final Color? textColor;

  const StatusBadge._({
    super.key,
    this.count,
    this.label,
    required this.color,
    this.textColor,
  });

  /// A small circular count badge (e.g. unread messages). Renders nothing
  /// when [count] is 0 or less. Displays "9+" above 9.
  factory StatusBadge.count({
    Key? key,
    required int count,
    Color color = AppColors.sos,
  }) =>
      StatusBadge._(key: key, count: count, color: color);

  /// A small rounded-rect text pill (e.g. "Host", "Ended").
  factory StatusBadge.label({
    Key? key,
    required String label,
    required Color color,
    Color? textColor,
  }) =>
      StatusBadge._(
        key: key,
        label: label,
        color: color,
        textColor: textColor,
      );

  @override
  Widget build(BuildContext context) {
    if (count != null) {
      if (count! <= 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Text(
          count! > 9 ? '9+' : '$count',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label ?? '',
        style: GoogleFonts.poppins(
          color: textColor ?? Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
