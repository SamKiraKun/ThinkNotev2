import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/extensions/context_extensions.dart';

class PinnedNoteCard extends StatelessWidget {
  const PinnedNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 136,
      padding: const EdgeInsets.only(left: 16, right: 14, top: 16, bottom: 14),
      decoration: BoxDecoration(
        gradient: AppGradients.pinnedCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   const Icon(Icons.push_pin, size: 14, color: AppColors.brandPurple),
                   const SizedBox(width: 4),
                   Text("PINNED NOTE", style: AppTypography.labelMedium.copyWith(color: AppColors.brandPurple)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Dream Life Plan ✨", 
                style: AppTypography.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 220,
                child: Text(
                  "A clear plan for the life I want to build and the person I want to become.", 
                  style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Icon(Icons.more_horiz, color: palette.textTertiary),
          )
        ],
      ),
    );
  }
}
