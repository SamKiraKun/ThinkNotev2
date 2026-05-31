import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../folders/presentation/widgets/folder_visuals.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../notes/presentation/controllers/notes_state.dart';
import '../../../notes/presentation/widgets/note_card.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../../../../shared/widgets/category_chip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFolderId = ref.watch(homeSelectedFolderProvider);
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;
    final syncEnabled = AppEnv.enableExperimentalSync;
    final syncState = ref.watch(syncControllerProvider);

    return SafeArea(
      bottom: false,
      child: notesAsync.when(
        data: (notesState) {
          final visibleNotes =
              notesState.filterNotes(folderId: selectedFolderId);
          final featuredNote = selectedFolderId == null
              ? notesState.featuredPinnedNote
              : visibleNotes.where((note) => note.isPinned).firstOrNull;
          final hasEmptyState = visibleNotes.isEmpty;
          final hasFeaturedNote = !hasEmptyState && featuredNote != null;
          final totalItemCount = 6 +
              (hasEmptyState
                  ? 1
                  : 2 + visibleNotes.length + (hasFeaturedNote ? 2 : 0));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              28,
              AppSpacing.xxl,
              AppSpacing.bottomNavReserved,
            ),
            itemCount: totalItemCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return AppHeader(
                  title: AppConstants.appName,
                  subtitle: syncEnabled
                      ? 'Good morning. Your notes stay on this device first and sync when you are online.'
                      : 'Good morning. Your notes stay on this device and work offline.',
                  brandStyle: true,
                  leading: const HeaderAvatar(label: 'T'),
                  trailing: syncEnabled
                      ? HeaderActionButton(
                          icon: syncState.isSyncing
                              ? Icons.sync_rounded
                              : syncState.lastError == null
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                          onPressed: () => _runSync(context, ref),
                        )
                      : null,
                );
              }

              if (index == 1) {
                return const SizedBox(height: AppSpacing.headerToSearch);
              }

              if (index == 2) {
                return AppSearchBar(
                  readOnly: true,
                  hintText: 'Search your notes, folders, tags...',
                  onTap: () {
                    ref.read(shellTabProvider.notifier).state = ShellTab.search;
                  },
                  onTrailingTap: () => _showSortSheet(context, ref, notesState),
                );
              }

              if (index == 3) {
                return const SizedBox(height: AppSpacing.searchToChips);
              }

              if (index == 4) {
                return SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, chipIndex) {
                      if (chipIndex == 0) {
                        return CategoryChip(
                          label: 'All',
                          selected: selectedFolderId == null,
                          backgroundColor: palette.surfacePrimary,
                          textColor: context.colors.onSurface,
                          onTap: () {
                            ref.read(homeSelectedFolderProvider.notifier).state =
                                null;
                          },
                        );
                      }

                      final folder = notesState.folders[chipIndex - 1];
                      final visuals = folderVisualsFor(folder.colorKey);
                      return CategoryChip(
                        label: folder.name,
                        emoji: folder.emoji,
                        selected: selectedFolderId == folder.id,
                        backgroundColor: visuals.backgroundColor,
                        textColor: visuals.accentColor,
                        onTap: () {
                          final notifier =
                              ref.read(homeSelectedFolderProvider.notifier);
                          notifier.state =
                              selectedFolderId == folder.id ? null : folder.id;
                        },
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.chipGap),
                    itemCount: notesState.folders.length + 1,
                  ),
                );
              }

              if (index == 5) {
                return const SizedBox(height: AppSpacing.chipsToPinned);
              }

              if (hasEmptyState) {
                return AppEmptyState(
                  icon: Icons.note_alt_outlined,
                  title: selectedFolderId == null
                      ? 'No notes yet'
                      : 'Nothing here yet',
                  message: selectedFolderId == null
                      ? 'Create your first note and it will appear here instantly.'
                      : 'Create a note in this folder or clear the folder filter.',
                  actionLabel: 'Create your first note',
                  onAction: () {
                    context.push(
                      RouteNames.editor,
                      extra: <String, dynamic>{
                        'initialFolderId':
                            selectedFolderId ?? notesState.defaultFolderId,
                      },
                    );
                  },
                );
              }

              var offset = 6;
              if (hasFeaturedNote) {
                if (index == offset) {
                  return _PinnedNoteCard(
                    noteTitle: featuredNote.displayTitle,
                    noteExcerpt: featuredNote.excerpt,
                    folderLabel:
                        notesState.folderById(featuredNote.folderId)?.displayName ??
                            'Unsorted',
                    dateLabel:
                        DateFormatter.formatFullDate(featuredNote.updatedAt),
                    onTap: () {
                      context.push(
                        RouteNames.editor,
                        extra: <String, dynamic>{'noteId': featuredNote.id},
                      );
                    },
                  );
                }

                if (index == offset + 1) {
                  return const SizedBox(height: AppSpacing.pinnedToRecent);
                }

                offset += 2;
              }

              if (index == offset) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Notes', style: AppTypography.titleMedium),
                    TextButton(
                      onPressed: () {
                        ref.read(shellTabProvider.notifier).state =
                            ShellTab.search;
                      },
                      child: Text(
                        'View all',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (index == offset + 1) {
                return const SizedBox(height: AppSpacing.recentHeaderToList);
              }

              final note = visibleNotes[index - offset - 2];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.noteCardGap),
                child: NoteCard(
                  note: note,
                  folder: notesState.folderById(note.folderId),
                  subtitle: DateFormatter.formatRelative(note.updatedAt),
                  previewLines: notesState.preferences.previewLines,
                  onTap: () {
                    context.push(
                      RouteNames.editor,
                      extra: <String, dynamic>{'noteId': note.id},
                    );
                  },
                  onPinTap: () => ref
                      .read(notesControllerProvider.notifier)
                      .togglePin(note.id),
                  onFavoriteTap: () => ref
                      .read(notesControllerProvider.notifier)
                      .toggleFavorite(note.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              'Unable to load your notes.',
              style: AppTypography.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet(
      BuildContext context, WidgetRef ref, NotesState notesState) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final currentOrder = notesState.preferences.defaultSortOrder;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sort notes', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                for (final sortOrder in NoteSortOrder.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sortOrder.label),
                    trailing: currentOrder == sortOrder
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.brandPrimary)
                        : null,
                    onTap: () {
                      ref
                          .read(notesControllerProvider.notifier)
                          .updatePreferences(
                            notesState.preferences
                                .copyWith(defaultSortOrder: sortOrder),
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                if (ref.read(homeSelectedFolderProvider) != null) ...[
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Clear folder filter'),
                    onTap: () {
                      ref.read(homeSelectedFolderProvider.notifier).state =
                          null;
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    await ref.read(syncControllerProvider.notifier).syncNow();
    final syncState = ref.read(syncControllerProvider);
    final message = syncState.lastError == null
        ? 'Sync complete.'
        : '${describeSyncErrorType(syncState.lastErrorType)}: ${syncState.lastError}';
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PinnedNoteCard extends StatelessWidget {
  const _PinnedNoteCard({
    required this.noteTitle,
    required this.noteExcerpt,
    required this.folderLabel,
    required this.dateLabel,
    required this.onTap,
  });

  final String noteTitle;
  final String noteExcerpt;
  final String folderLabel;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: Container(
        height: 156,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppGradients.pinnedCard,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          boxShadow: AppShadows.floatingCard,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'PINNED NOTE',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: 220,
                  child: Text(
                    noteTitle,
                    style: AppTypography.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: 220,
                  child: Text(
                    noteExcerpt,
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfacePrimary.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        folderLabel,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _PinnedIllustration(),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.surfacePrimary.withValues(alpha: 0.68),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_horiz_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 132,
          height: 92,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x33FFFFFF), Color(0x66FFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const Icon(
          Icons.terrain_rounded,
          size: 92,
          color: AppColors.brandLavender,
        ),
        const Positioned(
          top: 8,
          right: 24,
          child: Icon(
            Icons.flag_rounded,
            color: AppColors.brandPrimary,
          ),
        ),
      ],
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
