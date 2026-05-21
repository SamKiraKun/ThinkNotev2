import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class DividerWithLabel extends StatelessWidget {
  const DividerWithLabel({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.formDivider, thickness: 1)),
        const SizedBox(width: AppSpacing.dividerLineGap),
        Text(label, style: AppTypography.dividerLabel),
        const SizedBox(width: AppSpacing.dividerLineGap),
        const Expanded(child: Divider(color: AppColors.formDivider, thickness: 1)),
      ],
    );
  }
}