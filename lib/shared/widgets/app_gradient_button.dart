import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/accessibility_utils.dart';
import 'animated_tap_scale.dart';

class AppGradientButton extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double radius;
  final Gradient? gradient;
  final Color? disabledBackgroundColor;
  final Color? textColor;
  final TextStyle? textStyle;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;

  const AppGradientButton({
    super.key,
    required this.label,
    this.semanticsLabel,
    required this.onPressed,
    this.isLoading = false,
    this.height = AppSpacing.buttonHeight,
    this.radius = AppRadius.button,
    this.gradient,
    this.disabledBackgroundColor,
    this.textColor,
    this.textStyle,
    this.boxShadow,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      excludeSemantics: true,
      label: semanticsLabel ?? label,
      onTap: isDisabled ? null : onPressed,
      child: AnimatedTapScale(
        onTap: isLoading ? null : onPressed,
        disabled: isDisabled,
        builder: (context, state) {
          final duration = AccessibilityUtils.interactiveDuration(context);
          final overlayOpacity = state.isPressed
              ? 0.06
              : state.isHovered
                  ? 0.03
                  : 0.0;

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
              color: isDisabled
                  ? (disabledBackgroundColor ?? AppColors.buttonDisabledBackground)
                  : null,
              gradient: isDisabled ? null : (gradient ?? AppGradients.primaryButton),
              borderRadius: BorderRadius.circular(radius),
              border: state.isFocused
                  ? Border.all(color: AppColors.borderFocus, width: 2)
                  : null,
              boxShadow: isDisabled
                  ? const <BoxShadow>[]
                  : (boxShadow ?? AppShadows.buttonGlow),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: overlayOpacity == 0
                          ? Colors.transparent
                          : AppColors.surface.withValues(alpha: overlayOpacity),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
                Padding(
                  padding: padding ??
                      const EdgeInsets.symmetric(
                        horizontal: AppSpacing.buttonHorizontalPadding,
                        vertical: AppSpacing.buttonVerticalPadding,
                      ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: textColor ?? AppColors.buttonPrimaryText,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Text(
                          label,
                          textAlign: TextAlign.center,
                          style: (textStyle ?? AppTypography.buttonLabel).copyWith(
                            color: textColor ?? AppColors.buttonPrimaryText,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
