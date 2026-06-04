import 'dart:ui' show ImageFilter;
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
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 94,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: palette.glassSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(
                    color: palette.borderSoft.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                boxShadow: AppShadows.bottomNav,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _NavItem(
                        label: 'Dashboard',
                        icon: activeTab == ShellTab.home
                            ? Icons.home_rounded
                            : Icons.home_outlined,
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
                        label: 'Folders',
                        icon: activeTab == ShellTab.folders
                            ? Icons.folder_copy_rounded
                            : Icons.folder_copy_outlined,
                        isActive: activeTab == ShellTab.folders,
                        onTap: () => onTabSelected(ShellTab.folders),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _NavItem(
                        label: 'Profile',
                        icon: activeTab == ShellTab.profile
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        isActive: activeTab == ShellTab.profile,
                        onTap: () => onTabSelected(ShellTab.profile),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
          vertical: 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.brandPrimary : palette.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.navLabel.copyWith(
                color:
                    isActive ? AppColors.brandPrimary : palette.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 4 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
