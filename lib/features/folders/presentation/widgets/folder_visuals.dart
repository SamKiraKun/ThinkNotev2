import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class FolderVisuals {
  const FolderVisuals({
    required this.backgroundColor,
    required this.accentColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color accentColor;
  final IconData icon;
}

FolderVisuals folderVisualsFor(String colorKey) {
  switch (colorKey) {
    case 'study':
      return const FolderVisuals(
        backgroundColor: AppColors.studyBackground,
        accentColor: AppColors.studyText,
        icon: Icons.menu_book_rounded,
      );
    case 'ideas':
      return const FolderVisuals(
        backgroundColor: AppColors.ideasBackground,
        accentColor: AppColors.ideasText,
        icon: Icons.lightbulb_outline_rounded,
      );
    case 'work':
      return const FolderVisuals(
        backgroundColor: AppColors.workBackground,
        accentColor: AppColors.workText,
        icon: Icons.laptop_mac_rounded,
      );
    case 'journal':
      return const FolderVisuals(
        backgroundColor: AppColors.journalBackground,
        accentColor: AppColors.journalText,
        icon: Icons.edit_note_rounded,
      );
    case 'personal':
      return const FolderVisuals(
        backgroundColor: AppColors.personalBackground,
        accentColor: AppColors.personalText,
        icon: Icons.favorite_border_rounded,
      );
    default:
      return const FolderVisuals(
        backgroundColor: AppColors.personalBackground,
        accentColor: AppColors.personalText,
        icon: Icons.folder_open_rounded,
      );
  }
}
