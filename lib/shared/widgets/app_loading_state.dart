import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.title = 'Preparing your workspace',
    this.message = 'Loading your latest notes securely.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: palette.surfacePrimary.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            border: Border.all(color: palette.borderSoft),
            boxShadow: AppShadows.softCard,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.96, end: 1),
                duration: const Duration(milliseconds: 720),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandPrimary.withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 24,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
