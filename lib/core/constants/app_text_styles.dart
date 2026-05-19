import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading = GoogleFonts.dmSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle title = GoogleFonts.dmSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.dmSans(
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  static TextStyle caption = GoogleFonts.dmSans(
    fontSize: 12,
    color: AppColors.textMuted,
  );

  static TextStyle label = GoogleFonts.dmSans(
    fontSize: 12,
    color: AppColors.textLabel,
  );

  static TextStyle mono = const TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
  );

  static TextStyle tag = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  static TextStyle navSelected = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.navSelected,
  );

  static TextStyle navUnselected = GoogleFonts.dmSans(
    fontSize: 12,
    color: AppColors.navUnselected,
  );

  static TextStyle button = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static TextStyle amount = GoogleFonts.spaceGrotesk(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.success,
  );

  static TextStyle brandHeading = GoogleFonts.spaceGrotesk(
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static TextStyle displayHeading = GoogleFonts.cormorantGaramond(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
