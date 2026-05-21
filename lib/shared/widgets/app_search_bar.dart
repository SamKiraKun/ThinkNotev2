import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

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
      height: 54,
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.borderSoft),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: palette.textTertiary,
            size: 24,
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
            IconButton(
              onPressed: onTrailingTap,
              style: IconButton.styleFrom(
                backgroundColor: palette.surfaceAccent,
                foregroundColor: AppColors.brandPrimary,
                minimumSize: const Size(38, 38),
                padding: EdgeInsets.zero,
              ),
              icon: Icon(trailingIcon, size: 20),
            ),
        ],
      ),
    );
  }
}
