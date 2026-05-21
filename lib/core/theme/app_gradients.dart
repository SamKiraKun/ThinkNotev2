import 'package:flutter/material.dart';

class AppGradients {
  static const double _deg135 = 135 * 3.1415926535 / 180;
  static const double _deg145 = 145 * 3.1415926535 / 180;

  static const LinearGradient brandText = LinearGradient(
    colors: [Color(0xFF5C8DFF), Color(0xFF6F63FF), Color(0xFF9A5CFF)],
    stops: [0.0, 0.5, 1.0],
    transform: GradientRotation(_deg135),
  );

  static const LinearGradient primaryButton = LinearGradient(
    colors: [Color(0xFF5B7CFF), Color(0xFF6F63FF), Color(0xFF9A5CFF)],
    stops: [0.0, 0.52, 1.0],
    transform: GradientRotation(_deg135),
  );

  static const LinearGradient authPrimaryButton = LinearGradient(
    colors: [Color(0xFF4F8DFF), Color(0xFF6F63FF), Color(0xFF9A5CFF)],
    stops: [0.0, 0.52, 1.0],
    transform: GradientRotation(_deg135),
  );

  static const LinearGradient authAppIcon = LinearGradient(
    colors: [Color(0xFFE6D7FF), Color(0xFFBBA0FF), Color(0xFF8D75EF)],
    stops: [0.0, 0.55, 1.0],
    transform: GradientRotation(_deg145),
  );

  static const LinearGradient bottomMountain = LinearGradient(
    colors: [Color(0xFFF6D9FF), Color(0xFFBBA0FF), Color(0xFF7C6DF0)],
    stops: [0.0, 0.48, 1.0],
    transform: GradientRotation(_deg145),
  );

  static const LinearGradient createAccountPanel = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF6F2FF), Color(0xFFEEF3FF)],
    stops: [0.0, 0.56, 1.0],
    transform: GradientRotation(_deg135),
  );

  static const LinearGradient headlineAccent = LinearGradient(
    colors: [Color(0xFF5C8DFF), Color(0xFF6F63FF), Color(0xFF9A5CFF)],
    stops: [0.0, 0.45, 1.0],
    transform: GradientRotation(_deg135),
  );

  static const LinearGradient heroNotebook = LinearGradient(
    colors: [Color(0xFFE6D7FF), Color(0xFFBBA0FF), Color(0xFF8D75EF)],
    stops: [0.0, 0.5, 1.0],
    transform: GradientRotation(_deg145),
  );

  static const LinearGradient heroPen = LinearGradient(
    colors: [Color(0xFFDCD2FF), Color(0xFF9B86F6)],
    stops: [0.0, 1.0],
    transform: GradientRotation(_deg145),
  );

  static const LinearGradient pinnedCard = LinearGradient(
    colors: [Color(0xFFF2ECFF), Color(0xFFFBE9F5), Color(0xFFE9F1FF)],
    stops: [0.0, 0.46, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryCta = primaryButton;
}
