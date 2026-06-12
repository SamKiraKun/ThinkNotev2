import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: palette.surfacePrimary.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            border: Border.all(color: palette.borderPrimary),
            boxShadow: AppShadows.softCard,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.textDanger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.textDanger,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                style: AppTypography.titleLarge,
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
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(retryLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
