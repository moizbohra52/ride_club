import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Standardized bottom sheet for RideClub.
///
/// Wraps [Get.bottomSheet] with the app's drag-handle style, consistent
/// padding, and a rounded top surface pulled from the theme. Use [show] to
/// present any [child] (e.g. the members list, member detail, filters).
///
/// Example:
/// ```dart
/// RideBottomSheet.show(
///   context,
///   title: 'Riders on the map',
///   child: const MyMembersList(),
/// );
/// ```
class RideBottomSheet {
  RideBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required Widget child,
    bool isScrollControlled = false,
    double? maxHeightFactor,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Get.bottomSheet<T>(
      SafeArea(
        child: Container(
          constraints: maxHeightFactor != null
              ? BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * maxHeightFactor,
                )
              : null,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (title != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
      backgroundColor: scheme.surface,
      isScrollControlled: isScrollControlled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 8,
    );
  }

  /// A drag handle matching the theme's bottom-sheet handle color.
  static Widget handle(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        height: 4,
        width: 36,
        decoration: BoxDecoration(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
