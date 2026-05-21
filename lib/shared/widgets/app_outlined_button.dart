import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/accessibility_utils.dart';
import 'animated_tap_scale.dart';

class AppOutlinedButton extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;
  final double height;
  final double radius;

  const AppOutlinedButton({
    super.key,
    required this.label,
    this.semanticsLabel,
    required this.onPressed,
    this.height = AppSpacing.buttonHeight,
    this.radius = AppRadius.button,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      excludeSemantics: true,
      label: semanticsLabel ?? label,
      child: AnimatedTapScale(
        onTap: onPressed,
        disabled: isDisabled,
        builder: (context, state) {
          final duration = AccessibilityUtils.interactiveDuration(context);
          final backgroundColor = isDisabled
              ? AppColors.surfaceMuted
              : state.isPressed
                  ? AppColors.surfaceLavender
                  : state.isHovered
                      ? AppColors.surfaceSoft
                      : AppColors.buttonSecondaryBackground;

          final borderColor = state.isFocused
              ? AppColors.borderFocus
              : isDisabled
                  ? AppColors.borderDisabled
                  : AppColors.buttonSecondaryBorder;

          final textColor = isDisabled
              ? AppColors.buttonDisabledText
              : state.isHovered || state.isPressed
                  ? AppColors.brandPrimaryDark
                  : AppColors.buttonSecondaryText;

          return AnimatedContainer(
            duration: duration,
            curve: AppConstants.interactiveCurve,
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: AppConstants.minimumTapTarget,
              minWidth: AppConstants.minimumTapTarget,
            ),
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor,
                width: state.isFocused ? 2 : 1.5,
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonHorizontalPadding,
              vertical: AppSpacing.buttonVerticalPadding,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.buttonLabel.copyWith(color: textColor),
            ),
          );
        },
      ),
    );
  }
}
