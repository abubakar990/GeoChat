import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF121826);
  static const Color surface = Color(0xFF1A2235);
  static const Color surfaceVariant = Color(0xFF1F2D44);
  static const Color primary = Color(0xFF007BFF);
  static const Color primaryDark = Color(0xFF0056CC);
  static const Color encrypted = Color(0xFF00C853);
  static const Color encryptedDark = Color(0xFF00963E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF6B7A99);
  static const Color divider = Color(0xFF2A3A55);
  static const Color error = Color(0xFFFF4444);
  static const Color warning = Color(0xFFFFB300);
  static const Color online = Color(0xFF4CAF50);
  static const Color cardBorder = Color(0xFF2A3A55);
  static const Color inputFill = Color(0xFF1F2D44);
  static const Color messageSelf = Color(0xFF007BFF);
  static const Color messageOther = Color(0xFF1F2D44);
  static const Color overlayDark = Color(0xCC000000);
  static const Color shimmerBase = Color(0xFF1F2D44);
  static const Color shimmerHighlight = Color(0xFF2A3A55);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF007BFF), Color(0xFF0056CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF121826), Color(0xFF1A2235)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient encryptedGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00963E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alertGradient = LinearGradient(
    colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
