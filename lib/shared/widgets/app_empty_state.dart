import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palette.borderSoft),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom Pure Flutter Visual Mockup Illustration
          SizedBox(
            height: 120,
            width: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft background glow
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
                // Rotated background note sheet card
                Transform.rotate(
                  angle: -0.12,
                  child: Container(
                    width: 52,
                    height: 68,
                    decoration: BoxDecoration(
                      color: palette.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.borderPrimary),
                    ),
                  ),
                ),
                // Rotated background note sheet card #2
                Transform.rotate(
                  angle: 0.08,
                  child: Container(
                    width: 52,
                    height: 68,
                    decoration: BoxDecoration(
                      color: palette.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.borderPrimary),
                    ),
                  ),
                ),
                // Central main note sheet card
                Container(
                  width: 52,
                  height: 68,
                  decoration: BoxDecoration(
                    color: palette.surfacePrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.borderPrimary),
                    boxShadow: AppShadows.floatingCard,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 24,
                    color: AppColors.brandPrimary,
                  ),
                ),
                // Sparkle decoration #1
                Positioned(
                  top: 14,
                  right: 24,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.brandLavender.withValues(alpha: 0.8),
                    size: 16,
                  ),
                ),
                // Sparkle decoration #2
                Positioned(
                  bottom: 18,
                  left: 20,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.brandPrimaryLight,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Headline Title
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Description Message
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          // Massive Action Button
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                actionLabel!,
                style: AppTypography.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                elevation: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
