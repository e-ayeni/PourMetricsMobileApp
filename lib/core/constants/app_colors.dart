import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFF59E0B);
  static const Color primaryDark = Color(0xFFD97706);
  static const Color primaryLight = Color(0xFFFFF8E1);

  // Backgrounds
  static const Color scaffold = Color(0xFFF8F8F8);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF5F5F5);

  // Borders
  static const Color border = Color(0xFFEEEEEE);
  static const Color borderInput = Color(0xFFE0E0E0);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textMuted = Colors.grey;
  static const Color textLabel = Color(0xFF757575);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Colors.orange;
  static const Color info = Color(0xFF2563EB);

  // Nav / app bar
  static const Color navBackground = Colors.white;
  static const Color navSelected = primaryDark;
  static const Color navUnselected = Colors.grey;
}
