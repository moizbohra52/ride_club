import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final ColorScheme scheme = Get.theme.colorScheme;
    final bool isDark = Get.theme.brightness == Brightness.dark;

    Get.rawSnackbar(
      snackPosition: SnackPosition.TOP,
      snackStyle: SnackStyle.FLOATING,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      borderRadius: 16,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      boxShadows: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      duration: const Duration(seconds: 3),
      dismissDirection: DismissDirection.horizontal,
      messageText: _SnackContent(
        title: title,
        message: message,
        color: color,
        icon: icon,
        scheme: scheme,
        isDark: isDark,
      ),
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

/// The card body for a [UiHelpers] snackbar: a surface pill with a colored
/// left accent bar, a tinted icon chip, and a title + message column.
class _SnackContent extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final ColorScheme scheme;
  final bool isDark;

  const _SnackContent({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.12),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Colored accent bar.
              Container(width: 5, color: color),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        message,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
