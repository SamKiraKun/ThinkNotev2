import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextTheme get textTheme => GoogleFonts.interTextTheme();

  static final TextStyle display = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 42 / 36,
    letterSpacing: -1.1,
  );

  static final TextStyle headingLarge = GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 36 / 30,
    letterSpacing: -0.8,
  );

  static final TextStyle headingMedium = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 34 / 28,
    letterSpacing: -0.8,
  );

  static final TextStyle headingSmall = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 28 / 22,
    letterSpacing: -0.4,
  );

  static final TextStyle title = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 22 / 17,
    letterSpacing: -0.2,
  );

  static final TextStyle body = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: -0.1,
  );

  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0,
  );

  static final TextStyle label = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0.1,
  );

  static final TextStyle statusTime = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 18 / 14,
    letterSpacing: -0.2,
  );

  static final TextStyle brandLogo = display.copyWith(
    fontSize: 46,
    height: 54 / 46,
    letterSpacing: -1.4,
    color: AppColors.brandPrimary,
  );

  static final TextStyle tagline = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 22 / 15,
    letterSpacing: -0.1,
  );

  static final TextStyle headlinePrimary = headingLarge;

  static final TextStyle headlineAccent = GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 36 / 30,
    letterSpacing: -0.8,
    color: AppColors.brandPrimary,
  );

  static final TextStyle bodyLarge = body;

  static final TextStyle headline = headingMedium;

  static final TextStyle subtitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: -0.1,
  );

  static final TextStyle subtitleAccent = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    letterSpacing: -0.1,
    color: AppColors.textAccent,
  );

  static final TextStyle inputText = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 22 / 16,
    letterSpacing: -0.1,
  );

  static final TextStyle inputPlaceholder = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 22 / 16,
    letterSpacing: -0.1,
  );

  static final TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 21 / 14,
    letterSpacing: 0,
  );

  static final TextStyle buttonLabel = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
    letterSpacing: -0.1,
    color: AppColors.textInverse,
  );

  static final TextStyle linkMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    letterSpacing: 0,
    color: AppColors.textLink,
  );

  static final TextStyle socialButtonLabel = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0,
    color: AppColors.socialButtonText,
  );

  static final TextStyle dividerLabel = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    letterSpacing: 0,
  );

  static final TextStyle createAccountTitle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    letterSpacing: 0,
  );

  static final TextStyle createAccountLink = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 22 / 15,
    letterSpacing: -0.1,
    color: AppColors.textLink,
  );

  static final TextStyle footer = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 16 / 11,
    letterSpacing: 0,
  );

  static final TextStyle footerLink = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 16 / 11,
    letterSpacing: 0,
    color: AppColors.textLink,
  );

  static final TextStyle titleLarge = headingSmall;

  static final TextStyle titleMedium = title;

  static final TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 20 / 15,
    letterSpacing: -0.1,
  );

  static final TextStyle bodySmall = caption;

  static final TextStyle labelMedium = label;

  static final TextStyle navLabel = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: -0.1,
  );
}
