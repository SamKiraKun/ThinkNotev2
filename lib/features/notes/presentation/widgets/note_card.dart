import 'package:flutter/material.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/presentation/widgets/folder_visuals.dart';
import '../../data/models/note_model.dart';
import '../../domain/entities/note_entity.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.folder,
    required this.subtitle,
    required this.previewLines,
    required this.onTap,
    this.onPinTap,
    this.onFavoriteTap,
    this.trailing,
  });

  final NoteModel note;
  final FolderModel? folder;
  final String subtitle;
  final int previewLines;
  final VoidCallback onTap;
  final VoidCallback? onPinTap;
  final VoidCallback? onFavoriteTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visuals = folderVisualsFor(folder?.colorKey ?? 'personal');
    final metadataLabel = folder?.displayName ?? 'Unsorted';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.borderSoft),
          boxShadow: AppShadows.softCard,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: visuals.backgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                visuals.icon,
                color: visuals.accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.excerpt,
                    maxLines: previewLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetaPill(
                        label: metadataLabel,
                        backgroundColor: visuals.backgroundColor,
                        textColor: visuals.accentColor,
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                      if (note.tags.isNotEmpty)
                        Text(
                          '#${note.tags.first}',
                          style: AppTypography.bodySmall.copyWith(
                            color: palette.textTertiary,
                          ),
                        ),
                      if (AppEnv.enableExperimentalSync) ...[
                        Icon(
                          switch (note.syncStatus) {
                            NoteSyncStatus.synced => Icons.cloud_done_outlined,
                            NoteSyncStatus.pendingCreate ||
                            NoteSyncStatus.pendingUpdate ||
                            NoteSyncStatus.pendingDelete =>
                              Icons.cloud_upload_outlined,
                            NoteSyncStatus.failed => Icons.cloud_off_outlined,
                          },
                          size: 13,
                          color: switch (note.syncStatus) {
                            NoteSyncStatus.synced => const Color(0xFF10B981),
                            NoteSyncStatus.pendingCreate ||
                            NoteSyncStatus.pendingUpdate ||
                            NoteSyncStatus.pendingDelete =>
                              AppColors.brandPrimary,
                            NoteSyncStatus.failed => AppColors.textDanger,
                          },
                        ),
                        Text(
                          note.syncStatus.label,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: switch (note.syncStatus) {
                              NoteSyncStatus.synced => const Color(0xFF10B981),
                              NoteSyncStatus.pendingCreate ||
                              NoteSyncStatus.pendingUpdate ||
                              NoteSyncStatus.pendingDelete =>
                                AppColors.brandPrimary,
                              NoteSyncStatus.failed => AppColors.textDanger,
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              children: [
                if (onPinTap != null)
                  IconButton(
                    onPressed: onPinTap,
                    icon: Icon(
                      note.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 20,
                      color: note.isPinned
                          ? AppColors.brandPrimary
                          : palette.textTertiary,
                    ),
                  ),
                if (onFavoriteTap != null)
                  IconButton(
                    onPressed: onFavoriteTap,
                    icon: Icon(
                      note.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 20,
                      color: note.isFavorite
                          ? AppColors.brandPrimary
                          : palette.textTertiary,
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(color: textColor),
      ),
    );
  }
}
