import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../controllers/folders_controller.dart';
import '../widgets/folder_visuals.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final segment = ref.watch(foldersSegmentProvider);

    return SafeArea(
      bottom: false,
      child: notesAsync.when(
        data: (notesState) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              28,
              AppSpacing.xxl,
              AppSpacing.bottomNavReserved,
            ),
            children: [
              AppHeader(
                title: 'Folders',
                subtitle: 'Organize notes into folders, tags, and collections.',
                trailing: HeaderActionButton(
                  icon: Icons.cloud_sync_outlined,
                  onPressed: () => _showSnack(
                    context,
                    'Folders and tags are local-first and ready for sync.',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.headerToSearch),
              AppSearchBar(
                readOnly: true,
                hintText: 'Search your notes, folders, tags...',
                onTap: () {
                  ref.read(shellTabProvider.notifier).state = ShellTab.search;
                },
                onTrailingTap: () {
                  ref.read(shellTabProvider.notifier).state = ShellTab.search;
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              _SegmentedToggle(
                value: segment,
                onChanged: (value) =>
                    ref.read(foldersSegmentProvider.notifier).state = value,
              ),
              const SizedBox(height: AppSpacing.xxl),
              switch (segment) {
                FolderViewSegment.folders => _FoldersGrid(
                    onCreateFolder: () => _showCreateFolderDialog(context, ref),
                  ),
                FolderViewSegment.tags => _TagsSection(
                    onCreateTag: () => _showCreateTagDialog(context, ref),
                  ),
                FolderViewSegment.collections => _CollectionsSection(
                    onOpenTrash: () => context.push(RouteNames.trash),
                  ),
              },
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load folders.',
            style: AppTypography.bodyLarge,
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateFolderDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Folder name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (created == true) {
      await ref
          .read(notesControllerProvider.notifier)
          .createFolder(controller.text);
    }
  }

  Future<void> _showCreateTagDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Tag label',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (created == true) {
      await ref
          .read(notesControllerProvider.notifier)
          .createTag(controller.text);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.value,
    required this.onChanged,
  });

  final FolderViewSegment value;
  final ValueChanged<FolderViewSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final segment in FolderViewSegment.values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(segment),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: value == segment
                        ? AppColors.brandPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    switch (segment) {
                      FolderViewSegment.folders => 'Folders',
                      FolderViewSegment.tags => 'Tags',
                      FolderViewSegment.collections => 'Collections',
                    },
                    style: AppTypography.bodyMedium.copyWith(
                      color: value == segment
                          ? context.colors.onPrimary
                          : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoldersGrid extends ConsumerWidget {
  const _FoldersGrid({
    required this.onCreateFolder,
  });

  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(notesControllerProvider).valueOrNull;
    if (notesState == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Folders', style: AppTypography.titleMedium),
            TextButton(
              onPressed: () =>
                  ref.read(shellTabProvider.notifier).state = ShellTab.home,
              child: Text(
                'View notes',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          itemCount: notesState.folderSummaries.length + 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            if (index == notesState.folderSummaries.length) {
              return _CreateFolderCard(onTap: onCreateFolder);
            }

            final summary = notesState.folderSummaries[index];
            return _FolderCard(
              title: summary.folder.displayName,
              noteCount: summary.noteCount,
              colorKey: summary.folder.colorKey,
              onTap: () {
                ref.read(homeSelectedFolderProvider.notifier).state =
                    summary.folder.id;
                ref.read(shellTabProvider.notifier).state = ShellTab.home;
              },
              onRename: () => _showRenameFolderDialog(
                  context, ref, summary.folder.id, summary.folder.name),
              onDelete: summary.folder.isSystem
                  ? null
                  : () => _confirmDeleteFolder(
                      context, ref, summary.folder.id, summary.folder.name),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showRenameFolderDialog(
    BuildContext context,
    WidgetRef ref,
    String folderId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (renamed == true) {
      await ref
          .read(notesControllerProvider.notifier)
          .renameFolder(folderId, controller.text);
    }
  }

  Future<void> _confirmDeleteFolder(
    BuildContext context,
    WidgetRef ref,
    String folderId,
    String folderName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: 'Delete folder?',
        message: 'Notes in $folderName will be moved to your default folder.',
        confirmLabel: 'Delete',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      await ref.read(notesControllerProvider.notifier).deleteFolder(folderId);
    }
  }
}

class _TagsSection extends ConsumerWidget {
  const _TagsSection({
    required this.onCreateTag,
  });

  final VoidCallback onCreateTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(notesControllerProvider).valueOrNull;
    if (notesState == null) {
      return const SizedBox.shrink();
    }

    if (notesState.tagSummaries.isEmpty) {
      return AppEmptyState(
        icon: Icons.sell_outlined,
        title: 'No tags yet',
        message: 'Create a tag to group notes across different folders.',
        actionLabel: 'Create tag',
        onAction: onCreateTag,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tags', style: AppTypography.titleMedium),
            TextButton(
              onPressed: onCreateTag,
              child: Text(
                'New tag',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final summary in notesState.tagSummaries)
              TagChip(
                label: summary.tag.displayLabel,
                count: summary.noteCount,
                onTap: () {
                  ref.read(shellTabProvider.notifier).state = ShellTab.search;
                },
                onDelete: () => ref
                    .read(notesControllerProvider.notifier)
                    .deleteTag(summary.tag.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _CollectionsSection extends ConsumerWidget {
  const _CollectionsSection({
    required this.onOpenTrash,
  });

  final VoidCallback onOpenTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(notesControllerProvider).valueOrNull;
    if (notesState == null) {
      return const SizedBox.shrink();
    }

    final items =
        <({String title, String subtitle, IconData icon, VoidCallback onTap})>[
      (
        title: 'Pinned',
        subtitle:
            '${notesState.activeNotes.where((note) => note.isPinned).length} notes',
        icon: Icons.push_pin_rounded,
        onTap: () {
          ref.read(shellTabProvider.notifier).state = ShellTab.search;
          ref.read(homeSelectedFolderProvider.notifier).state = null;
        },
      ),
      (
        title: 'Favorites',
        subtitle: '${notesState.favoriteNotes.length} notes',
        icon: Icons.star_rounded,
        onTap: () =>
            ref.read(shellTabProvider.notifier).state = ShellTab.search,
      ),
      (
        title: 'Recently edited',
        subtitle: '${notesState.activeNotes.take(5).length} notes',
        icon: Icons.schedule_rounded,
        onTap: () => ref.read(shellTabProvider.notifier).state = ShellTab.home,
      ),
      (
        title: 'Archive',
        subtitle: '${notesState.archivedNotes.length} notes',
        icon: Icons.archive_outlined,
        onTap: () => context.push(RouteNames.archive),
      ),
      (
        title: 'Trash',
        subtitle: '${notesState.trashedNotes.length} notes',
        icon: Icons.delete_outline_rounded,
        onTap: onOpenTrash,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _CollectionCard(
          title: item.title,
          subtitle: item.subtitle,
          icon: item.icon,
          onTap: item.onTap,
        );
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.title,
    required this.noteCount,
    required this.colorKey,
    required this.onTap,
    required this.onRename,
    this.onDelete,
  });

  final String title;
  final int noteCount;
  final String colorKey;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visuals = folderVisualsFor(colorKey);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: visuals.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.folder_outlined,
                    color: visuals.accentColor,
                    size: 30,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      onRename();
                    } else if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFolderCard extends StatelessWidget {
  const _CreateFolderCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.24),
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surfaceAccent,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Create New Folder',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brandPrimary),
            const Spacer(),
            Text(title, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
