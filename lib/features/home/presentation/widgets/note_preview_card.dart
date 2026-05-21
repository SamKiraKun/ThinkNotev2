import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_shadows.dart';

class NotePreviewCard extends StatelessWidget {
  final String title;
  final String category;
  final Color categoryColor;
  final Color categoryBgColor;
  final VoidCallback onTap;

  const NotePreviewCard({
    super.key,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.categoryBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 68,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: AppShadows.softCard,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: categoryBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.sticky_note_2, color: categoryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(category, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: AppColors.textPlaceholder),
              onPressed: () {},
            )
          ],
        ),
      ),
    );
  }
}
