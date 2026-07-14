import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../core/constants/app_constants.dart';

/// Owns the app's [ThemeMode], persisted in GetStorage.
///
/// Defaults to [ThemeMode.system]. Registered permanently so any screen can
/// toggle the theme via `Get.find<ThemeService>()`.
class ThemeService extends GetxService {
  final GetStorage _box = GetStorage();

  final Rx<ThemeMode> mode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    final String? saved = _box.read<String>(AppConstants.kThemeMode);
    mode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setMode(ThemeMode m) {
    mode.value = m;
    Get.changeThemeMode(m);
    _box.write(AppConstants.kThemeMode, m.name);
  }

  /// Cycle system → light → dark → system. Handy for a single toolbar button.
  void toggle() {
    final ThemeMode next = switch (mode.value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    setMode(next);
  }

  IconData get icon => switch (mode.value) {
        ThemeMode.system => Icons.brightness_auto,
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
      };
}
