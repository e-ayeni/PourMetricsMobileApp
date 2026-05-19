import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFC17D2B);
  static const Color primaryDark = Color(0xFF7A4A0F);
  static const Color primaryLight = Color(0xFFFDF3E3);
  static const Color gold = Color(0xFFD9A547);

  // Backgrounds
  static const Color scaffold = Color(0xFFFAF6F0);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFFDF3E3);

  // Dark mode
  static const Color midnight = Color(0xFF0F0A05);

  // Borders
  static const Color border = Color(0xFFEEEEEE);
  static const Color borderInput = Color(0xFFE0E0E0);

  // Text
  static const Color textPrimary = Color(0xFF1A1208);
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
