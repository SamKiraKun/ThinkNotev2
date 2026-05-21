import 'package:flutter/animation.dart';

class AppConstants {
  static const String appName = 'ThinkNote';
  static const double contentMaxWidth = 430;
  static const double minSupportedHeight = 640;
  static const double maxSupportedTextScale = 1.2;
  static const double minimumTapTarget = 44;
  static const Duration interactiveDuration = Duration(milliseconds: 180);
  static const Curve interactiveCurve = Curves.easeOutCubic;
}
