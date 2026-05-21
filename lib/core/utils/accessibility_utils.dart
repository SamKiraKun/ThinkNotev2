import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AccessibilityUtils {
  const AccessibilityUtils._();

  static bool reducedMotionOf(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);

    return (mediaQuery?.accessibleNavigation ?? false) ||
        ui.PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;
  }

  static double effectiveTextScale(
    BuildContext context, {
    double maxScale = AppConstants.maxSupportedTextScale,
  }) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return 1;
    }

    final scale = mediaQuery.textScaler.scale(1);
    return scale.clamp(1, maxScale);
  }

  static Duration interactiveDuration(BuildContext context) {
    return reducedMotionOf(context)
        ? Duration.zero
        : AppConstants.interactiveDuration;
  }
}