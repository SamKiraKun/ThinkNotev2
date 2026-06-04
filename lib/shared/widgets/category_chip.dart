import 'package:flutter/material.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 34,
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selected 
            ? null 
            : Border.all(color: palette.borderPrimary),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.textInverse : textColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: selected ? AppColors.textInverse : textColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
