import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.brandStyle = false,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool brandStyle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.lg),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: brandStyle
                    ? AppTypography.brandLogo
                        .copyWith(fontSize: 30, height: 1.1)
                    : AppTypography.headline.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class HeaderAvatar extends StatelessWidget {
  const HeaderAvatar({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandLavender,
        boxShadow: AppShadows.softCard,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.titleMedium.copyWith(
          color: context.colors.onPrimary,
        ),
      ),
    );
  }
}

class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: palette.surfacePrimary,
        foregroundColor: context.colors.onSurface,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        shadowColor: AppColors.shadowSoft,
        elevation: 0,
      ),
      icon: Icon(icon),
    );
  }
}
