import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.count,
    this.selected = false,
    this.onTap,
    this.onDelete,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.surfaceAccent : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : palette.borderPrimary,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: selected ? AppColors.brandPrimary : palette.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$count',
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ],
            if (onDelete != null) ...[
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
