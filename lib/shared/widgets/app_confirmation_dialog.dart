import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AlertDialog(
      title: Text(title, style: AppTypography.titleMedium),
      content: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(
          color: palette.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                isDestructive ? AppColors.textDanger : AppColors.brandPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
