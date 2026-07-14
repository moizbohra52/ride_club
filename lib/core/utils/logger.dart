import 'package:flutter/foundation.dart';

/// Tiny debug-only logger. Silent in release builds.
///
/// Prefer this over bare `print` so all diagnostics share a tag and are
/// stripped from production automatically.
class Log {
  Log._();

  static void d(Object? message, {String tag = 'RideTogether'}) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void e(Object? message, {Object? error, StackTrace? stack, String tag = 'RideTogether'}) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $message');
      if (error != null) debugPrint('[$tag]   $error');
      if (stack != null) debugPrint('[$tag]   $stack');
    }
  }
}
