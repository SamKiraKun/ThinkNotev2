import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../presentation/controllers/shell_controller.dart';
import '../../../../shared/widgets/gradient_fab.dart';

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    required this.onCreateTap,
  });

  final ShellTab activeTab;
  final ValueChanged<ShellTab> onTabSelected;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 94,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: palette.glassSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: AppShadows.bottomNav,
          ),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: _NavItem(
                    label: 'Dashboard',
                    icon: Icons.space_dashboard_rounded,
                    isActive: activeTab == ShellTab.home,
                    onTap: () => onTabSelected(ShellTab.home),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _NavItem(
                    label: 'Search',
                    icon: Icons.search_rounded,
                    isActive: activeTab == ShellTab.search,
                    onTap: () => onTabSelected(ShellTab.search),
                  ),
                ),
              ),
              const SizedBox(width: 76),
              Expanded(
                child: Center(
                  child: _NavItem(
                    label: 'Workspace',
                    icon: Icons.folder_open_rounded,
                    isActive: activeTab == ShellTab.folders,
                    onTap: () => onTabSelected(ShellTab.folders),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _NavItem(
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    isActive: activeTab == ShellTab.profile,
                    onTap: () => onTabSelected(ShellTab.profile),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -24,
          child: GradientFab(onTap: onCreateTap),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.brandPrimary : palette.textSecondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.navLabel.copyWith(
                color: isActive ? AppColors.brandPrimary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
