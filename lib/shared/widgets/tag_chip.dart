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

    // Filter out standard emojis to ensure monochrome icon prefix styling
    final cleanedLabel = label.replaceAll(
      RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{27BF}\u{E000}-\u{F8FF}\u{FE0F}\u{2011}-\u{26FF}]', unicode: true),
      '',
    ).trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.surfaceAccent : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : palette.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tag_rounded,
              size: 14,
              color: selected ? AppColors.brandPrimary : palette.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              cleanedLabel,
              style: AppTypography.bodyMedium.copyWith(
                color: selected ? AppColors.brandPrimary : palette.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$count',
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (onDelete != null) ...[
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandPrimary.withValues(alpha: 0.12)
                        : palette.surfaceSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: selected ? AppColors.brandPrimary : palette.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
