import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppShadows {
  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: AppColors.shadowSoft,
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: AppColors.shadowMedium,
      offset: Offset(0, 10),
      blurRadius: 28,
    ),
  ];

  static const List<BoxShadow> buttonGlow = [
    BoxShadow(
      color: AppColors.shadowPurpleGlow,
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  static const List<BoxShadow> heroGlow = [
    BoxShadow(
      color: AppColors.shadowIllustrationGlow,
      offset: Offset(0, 18),
      blurRadius: 44,
    ),
  ];

  static const List<BoxShadow> formCard = [
    BoxShadow(
      color: AppColors.shadowFormGlow,
      offset: Offset(0, 14),
      blurRadius: 36,
    ),
  ];

  static const List<BoxShadow> socialButton = [
    BoxShadow(
      color: AppColors.shadowSocialButton,
      offset: Offset(0, 10),
      blurRadius: 26,
    ),
  ];

  static const List<BoxShadow> illustrationGlow = [
    BoxShadow(
      color: AppColors.shadowIllustrationGlow,
      offset: Offset(0, 18),
      blurRadius: 44,
    ),
  ];

  static const List<BoxShadow> phoneFrame = [
    BoxShadow(
      color: Color(0x12101126),
      offset: Offset(0, 10),
      blurRadius: 34,
    ),
  ];

  static const List<BoxShadow> floatingCard = [
    BoxShadow(
      color: Color(0x19101126), // 10% opacity
      offset: Offset(0, 12),
      blurRadius: 36,
    ),
  ];

  static const List<BoxShadow> fabGlow = [
    BoxShadow(
      color: Color(0x406F63FF), // 25% opacity
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color(0x12101126), // 7% opacity
      offset: Offset(0, -10),
      blurRadius: 30,
    ),
  ];
}
