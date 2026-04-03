import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF13B8AA);
  static const Color primaryLight = Color(0xFF4CCEC4);
  static const Color primaryDark = Color(0xFF0E8D83);

  // Accent / Teal
  static const Color accent = Color(0xFF13B8AA);
  static const Color accentLight = Color(0xFFE6F8F6);

  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF8FAF8);
  static const Color surfaceLight = Color(0xFFF5F7F5);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Status colors
  static const Color success = Color(0xFF13B8AA);
  static const Color successLight = Color(0xFFE6F8F6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Card colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardSelectedBackground = Color(0xFFF0FDF9);
  static const Color cardSelectedBorder = Color(0xFF13B8AA);

  // Gradient for welcome screen
  static const List<Color> welcomeGradient = [
    Color(0xFF13B8AA),
    Color(0xFF0E8D83),
    Color(0xFF0A6E67),
  ];

  // Badge colors
  static const Color badgePopular = Color(0xFF13B8AA);
  static const Color badgePopularText = Color(0xFFFFFFFF);
  static const Color badgeVerified = Color(0xFF13B8AA);
  static const Color badgeActive = Color(0xFF13B8AA);

  // Bottom nav
  static const Color navActive = Color(0xFF13B8AA);
  static const Color navInactive = Color(0xFF9CA3AF);
}
