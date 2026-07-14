import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_colors.dart';

/// Consistent snackbars & dialogs used across all controllers.
///
/// Built on GetX overlays so they can be called from anywhere without a
/// [BuildContext].
class UiHelpers {
  UiHelpers._();

  static void success(String message, {String title = 'Done'}) =>
      _snack(title, message, AppColors.success, Icons.check_circle_outline);

  static void error(String message, {String title = 'Something went wrong'}) =>
      _snack(title, message, AppColors.danger, Icons.error_outline);

  static void info(String message, {String title = 'Heads up'}) =>
      _snack(title, message, AppColors.seed, Icons.info_outline);

  static void warning(String message, {String title = 'Careful'}) =>
      _snack(title, message, AppColors.warning, Icons.warning_amber_rounded);

  static void _snack(String title, String message, Color color, IconData icon) {
    // Avoid stacking duplicate snackbars.
    if (Get.isSnackbarOpen) Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      icon: Icon(icon, color: color),
      colorText: Get.theme.colorScheme.onSurface,
      backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
      duration: const Duration(seconds: 3),
      shouldIconPulse: false,
    );
  }

  /// Simple confirm dialog. Resolves `true` if the user confirms.
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
  }) async {
    final bool? result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(cancelText),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Get.back(result: true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
