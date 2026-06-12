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
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../notes/presentation/widgets/note_card.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../controllers/search_controller.dart';
import '../../../folders/presentation/widgets/folder_visuals.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesControllerProvider);
    final searchState = ref.watch(searchControllerProvider);
    final results = ref.watch(searchResultsProvider);
    final topPicks = ref.watch(searchTopPicksProvider);
    final hasFilters = ref.watch(hasSearchFiltersProvider);
    final palette = context.palette;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useCompactCards =
        MediaQuery.sizeOf(context).width < 360 || textScale > 1.2;

    if (_controller.text != searchState.query) {
      _controller.value = _controller.value.copyWith(
        text: searchState.query,
        selection: TextSelection.collapsed(offset: searchState.query.length),
      );
    }

    return SafeArea(
      bottom: false,
      child: notesAsync.when(
        data: (notesState) {
          final hasRecentSearches = notesState.recentSearches.isNotEmpty;
          final hasTopPicks = topPicks.isNotEmpty;
          final hasEmptyResults = results.isEmpty;
          final totalItemCount = 4 +
              (hasRecentSearches ? 4 : 0) +
              6 +
              (hasTopPicks ? 4 : 0) +
              2 +
              (hasEmptyResults ? 1 : results.length);

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
                  title: 'Search',
                  subtitle:
                      'Search notes, folders, and tags across your authenticated account.',
                  leading: const HeaderAvatar(label: 'T'),
                );
              }

              if (index == 1) {
                return const SizedBox(height: AppSpacing.headerToSearch);
              }

              if (index == 2) {
                return AppSearchBar(
                  controller: _controller,
                  hintText: 'Search notes, topics, or tags...',
                  autofocus: false,
                  onChanged: (value) {
                    ref.read(searchControllerProvider.notifier).setQuery(value);
                  },
                  onTrailingTap: () => _showSortSheet(context, ref, notesState),
                );
              }

              if (index == 3) {
                return const SizedBox(height: AppSpacing.xxl);
              }

              var offset = 4;
              if (hasRecentSearches) {
                if (index == offset) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Searches', style: AppTypography.titleMedium),
                      TextButton(
                        onPressed: () => ref
                            .read(notesControllerProvider.notifier)
                            .clearRecentSearches(),
                        child: Text(
                          'Clear all',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (index == offset + 1) {
                  return const SizedBox(height: AppSpacing.md);
                }

                if (index == offset + 2) {
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final recent in notesState.recentSearches)
                        _RecentSearchChip(
                          label: recent,
                          onTap: () {
                            ref
                                .read(searchControllerProvider.notifier)
                                .setQuery(recent);
                          },
                          onDelete: () {
                            ref
                                .read(notesControllerProvider.notifier)
                                .deleteRecentSearch(recent);
                          },
                        ),
                    ],
                  );
                }

                if (index == offset + 3) {
                  return const SizedBox(height: AppSpacing.xxl);
                }

                offset += 4;
              }

              if (index == offset) {
                return Text('Smart Filters', style: AppTypography.titleMedium);
              }

              if (index == offset + 1) {
                return const SizedBox(height: AppSpacing.md);
              }

              if (index == offset + 2) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ModeChip(
                        label: 'All',
                        icon: Icons.grid_view_rounded,
                        selected: searchState.mode == SearchMode.all,
                        onTap: () => ref
                            .read(searchControllerProvider.notifier)
                            .setMode(SearchMode.all),
                      ),
                      _ModeChip(
                        label: 'Notes',
                        icon: Icons.description_outlined,
                        selected: searchState.mode == SearchMode.notes,
                        onTap: () => ref
                            .read(searchControllerProvider.notifier)
                            .setMode(SearchMode.notes),
                      ),
                      _ModeChip(
                        label: 'Pinned',
                        icon: Icons.push_pin_outlined,
                        selected: searchState.mode == SearchMode.pinned,
                        onTap: () => ref
                            .read(searchControllerProvider.notifier)
                            .setMode(SearchMode.pinned),
                      ),
                      _ModeChip(
                        label: 'Favorites',
                        icon: Icons.star_border_rounded,
                        selected: searchState.mode == SearchMode.favorites,
                        onTap: () => ref
                            .read(searchControllerProvider.notifier)
                            .setMode(SearchMode.favorites),
                      ),
                    ],
                  ),
                );
              }

              if (index == offset + 3) {
                return const SizedBox(height: AppSpacing.md);
              }

              if (index == offset + 4) {
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _FilterChip(
                      label: searchState.folderId == null
                          ? 'All Folders'
                          : notesState.folderById(searchState.folderId)?.name ??
                              'Folder',
                      icon: Icons.folder_outlined,
                      onTap: () =>
                          _showFolderFilterSheet(context, ref, notesState),
                    ),
                    _FilterChip(
                      label: searchState.tagLabel == null
                          ? 'All Tags'
                          : '#${searchState.tagLabel}',
                      icon: Icons.sell_outlined,
                      onTap: () =>
                          _showTagFilterSheet(context, ref, notesState),
                    ),
                    _FilterChip(
                      label: searchState.sortOrder?.label ??
                          notesState.preferences.defaultSortOrder.label,
                      icon: Icons.sort_rounded,
                      onTap: () => _showSortSheet(context, ref, notesState),
                    ),
                  ],
                );
              }

              if (index == offset + 5) {
                return const SizedBox(height: AppSpacing.xxl);
              }

              offset += 6;

              if (hasTopPicks) {
                if (index == offset) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Picks For You',
                          style: AppTypography.titleMedium),
                      TextButton(
                        onPressed: () => ref
                            .read(shellTabProvider.notifier)
                            .state = ShellTab.home,
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
                  return const SizedBox(height: AppSpacing.md);
                }

                if (index == offset + 2) {
                  return SizedBox(
                    height: useCompactCards ? 236 : 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, topPickIndex) {
                        final note = topPicks[topPickIndex];
                        final folder = notesState.folderById(note.folderId);
                        return _TopPickCard(
                          noteTitle: note.displayTitle,
                          noteExcerpt: note.excerpt,
                          folderLabel: folder?.displayName ?? 'Unsorted',
                          folderColorKey: folder?.colorKey ?? 'personal',
                          isFavorite: note.isFavorite,
                          compact: useCompactCards,
                          onTap: () {
                            if (searchState.query.trim().isNotEmpty) {
                              ref
                                  .read(notesControllerProvider.notifier)
                                  .saveRecentSearch(searchState.query);
                            }
                            context.push(
                              RouteNames.editor,
                              extra: <String, dynamic>{
                                'noteId': note.id,
                                'initialNote': note,
                              },
                            );
                          },
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemCount: topPicks.length,
                    ),
                  );
                }

                if (index == offset + 3) {
                  return const SizedBox(height: AppSpacing.xxl);
                }

                offset += 4;
              }

              if (index == offset) {
                return Row(
                  children: [
                    Text('Search Results', style: AppTypography.titleMedium),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${results.length} results',
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                );
              }

              if (index == offset + 1) {
                return const SizedBox(height: AppSpacing.md);
              }

              offset += 2;

              if (hasEmptyResults) {
                return AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: searchState.query.trim().isEmpty && !hasFilters
                      ? 'Nothing to search yet'
                      : 'Nothing found',
                  message: searchState.query.trim().isEmpty && !hasFilters
                      ? 'Create a note or tap a recent search to start exploring.'
                      : 'Try a different keyword or clear one of the active filters.',
                  actionLabel: hasFilters ? 'Clear filters' : null,
                  onAction: hasFilters
                      ? () => ref
                          .read(searchControllerProvider.notifier)
                          .clearFilters()
                      : null,
                );
              }

              final note = results[index - offset];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.noteCardGap),
                child: NoteCard(
                  note: note,
                  folder: notesState.folderById(note.folderId),
                  subtitle: DateFormatter.formatRelative(note.updatedAt),
                  previewLines: notesState.preferences.previewLines,
                  onTap: () {
                    if (searchState.query.trim().isNotEmpty) {
                      ref
                          .read(notesControllerProvider.notifier)
                          .saveRecentSearch(searchState.query);
                    }
                    context.push(
                      RouteNames.editor,
                      extra: <String, dynamic>{
                        'noteId': note.id,
                        'initialNote': note,
                      },
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
        loading: () => const AppLoadingState(
          title: 'Indexing your workspace',
          message: 'Preparing notes, tags, and folders for search.',
        ),
        error: (error, _) => AppErrorState(
          title: 'Unable to load search',
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () async {
            await ref.read(notesControllerProvider.notifier).refresh();
          },
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context, WidgetRef ref, dynamic notesState) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surfacePrimary,
      builder: (context) {
        final searchState = ref.read(searchControllerProvider);
        final currentOrder =
            searchState.sortOrder ?? notesState.preferences.defaultSortOrder;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sort results', style: AppTypography.titleMedium),
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
                          .read(searchControllerProvider.notifier)
                          .setSortOrder(sortOrder);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFolderFilterSheet(
      BuildContext context, WidgetRef ref, dynamic notesState) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surfacePrimary,
      builder: (context) {
        final selected = ref.read(searchControllerProvider).folderId;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter by folder', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All folders'),
                  trailing: selected == null
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.brandPrimary)
                      : null,
                  onTap: () {
                    ref.read(searchControllerProvider.notifier).setFolder(null);
                    Navigator.of(context).pop();
                  },
                ),
                for (final folder in notesState.folders)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(folder.displayName),
                    trailing: selected == folder.id
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.brandPrimary)
                        : null,
                    onTap: () {
                      ref
                          .read(searchControllerProvider.notifier)
                          .setFolder(folder.id);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTagFilterSheet(
      BuildContext context, WidgetRef ref, dynamic notesState) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surfacePrimary,
      builder: (context) {
        final selected = ref.read(searchControllerProvider).tagLabel;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter by tag', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All tags'),
                  trailing: selected == null
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.brandPrimary)
                      : null,
                  onTap: () {
                    ref.read(searchControllerProvider.notifier).setTag(null);
                    Navigator.of(context).pop();
                  },
                ),
                for (final tag in notesState.tags)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tag.displayLabel),
                    trailing: selected == tag.label
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.brandPrimary)
                        : null,
                    onTap: () {
                      ref
                          .read(searchControllerProvider.notifier)
                          .setTag(tag.label);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandPrimary : palette.surfacePrimary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : palette.borderSoft,
            ),
            boxShadow: selected ? AppShadows.softCard : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color:
                    selected ? context.colors.onPrimary : palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: selected
                      ? context.colors.onPrimary
                      : palette.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: palette.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPickCard extends StatelessWidget {
  const _TopPickCard({
    required this.noteTitle,
    required this.noteExcerpt,
    required this.folderLabel,
    required this.folderColorKey,
    required this.isFavorite,
    required this.compact,
    required this.onTap,
  });

  final String noteTitle;
  final String noteExcerpt;
  final String folderLabel;
  final String folderColorKey;
  final bool isFavorite;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visuals = folderVisualsFor(folderColorKey);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: Container(
        width: compact ? 200 : 220,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(color: palette.borderSoft),
          boxShadow: AppShadows.softCard,
          gradient: LinearGradient(
            colors: [
              visuals.backgroundColor,
              visuals.backgroundColor.withValues(alpha: 0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isFavorite ? Icons.star_rounded : visuals.icon,
              color: visuals.accentColor,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              noteTitle,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              noteExcerpt,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: palette.surfacePrimary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                folderLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip({
    required this.label,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: palette.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 14,
              color: palette.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: palette.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
