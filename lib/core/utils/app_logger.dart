import 'package:flutter/foundation.dart';

/// Production-safe logger. Only prints in debug mode.
/// In release builds, all log calls are no-ops.
class AppLogger {
  AppLogger._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void warning(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ⚠️ $message');
    }
  }

  static void error(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[$tag] ❌ $message');
      if (error != null) debugPrint('[$tag]    $error');
    }
  }
}
