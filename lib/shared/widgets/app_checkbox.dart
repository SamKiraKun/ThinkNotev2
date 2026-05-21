import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/accessibility_utils.dart';
import 'animated_tap_scale.dart';

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.semanticsLabel,
    this.size = 22,
    this.labelStyle,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticsLabel;
  final double size;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;

    return Semantics(
      checked: value,
      enabled: !isDisabled,
      inMutuallyExclusiveGroup: false,
      label: semanticsLabel,
      onTap: isDisabled ? null : () => onChanged?.call(!value),
      child: AnimatedTapScale(
        onTap: isDisabled ? null : () => onChanged?.call(!value),
        disabled: isDisabled,
        builder: (context, state) {
          final duration = AccessibilityUtils.interactiveDuration(context);
          final backgroundColor = isDisabled
              ? AppColors.buttonDisabledBackground
              : value
                  ? state.isHovered
                      ? AppColors.brandPrimaryDark
                      : AppColors.checkboxActive
                  : AppColors.surface;
          final borderColor = state.isFocused
              ? AppColors.borderFocus
              : value
                  ? Colors.transparent
                  : AppColors.buttonSecondaryBorder;

          return AnimatedContainer(
            duration: duration,
            curve: AppConstants.interactiveCurve,
            constraints: const BoxConstraints(
              minWidth: AppConstants.minimumTapTarget,
              minHeight: AppConstants.minimumTapTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: duration,
                  curve: AppConstants.interactiveCurve,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor,
                      width: state.isFocused ? 2 : 1.4,
                    ),
                  ),
                  child: value
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.checkboxIcon,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: (labelStyle ?? AppTypography.bodyMedium).copyWith(
                      color: isDisabled
                          ? AppColors.buttonDisabledText
                          : AppColors.textSecondary,
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
