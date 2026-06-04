import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

import '../../../../shared/widgets/animated_tap_scale.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search your notes...',
    this.onChanged,
    this.onTap,
    this.onTrailingTap,
    this.trailingIcon = Icons.tune_rounded,
    this.readOnly = false,
    this.autofocus = false,
    this.showTrailingAction = true,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingTap;
  final IconData trailingIcon;
  final bool readOnly;
  final bool autofocus;
  final bool showTrailingAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 52,
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: palette.textTertiary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: palette.textPlaceholder,
                ),
              ),
              style: AppTypography.bodyLarge,
              textInputAction: TextInputAction.search,
            ),
          ),
          if (showTrailingAction)
            AnimatedTapScale(
              onTap: onTrailingTap,
              tapScale: 0.9,
              builder: (context, state) {
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.surfaceAccent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    trailingIcon,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
