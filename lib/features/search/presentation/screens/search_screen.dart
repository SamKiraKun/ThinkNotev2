import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../notes/presentation/widgets/note_card.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../controllers/search_controller.dart';

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
    final syncEnabled = AppEnv.enableExperimentalSync;
    final syncState = ref.watch(syncControllerProvider);

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
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              28,
              AppSpacing.xxl,
              AppSpacing.bottomNavReserved,
            ),
            children: [
              AppHeader(
                title: AppConstants.appName,
                subtitle:
                    'Search notes, folders, and tags instantly on this device.',
                brandStyle: true,
                leading: const HeaderAvatar(label: 'T'),
                trailing: syncEnabled
                    ? HeaderActionButton(
                        icon: syncState.isSyncing
                            ? Icons.sync_rounded
                            : Icons.cloud_done_outlined,
                        onPressed: () => _showSnack(
                          context,
                          'Search stays local for speed while synced notes update in the background.',
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.headerToSearch),
              AppSearchBar(
                controller: _controller,
                hintText: 'Search notes, topics, or tags...',
                autofocus: false,
                onChanged: (value) {
                  ref.read(searchControllerProvider.notifier).setQuery(value);
                },
                onTrailingTap: () => _showSortSheet(context, ref, notesState),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (notesState.recentSearches.isNotEmpty) ...[
                Row(
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
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final recent in notesState.recentSearches)
                      TagChip(
                        label: recent,
                        onTap: () {
                          ref
                              .read(searchControllerProvider.notifier)
                              .setQuery(recent);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
              Text('Smart Filters', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ModeChip(
                      label: 'All',
                      selected: searchState.mode == SearchMode.all,
                      onTap: () => ref
                          .read(searchControllerProvider.notifier)
                          .setMode(SearchMode.all),
                    ),
                    _ModeChip(
                      label: 'Notes',
                      selected: searchState.mode == SearchMode.notes,
                      onTap: () => ref
                          .read(searchControllerProvider.notifier)
                          .setMode(SearchMode.notes),
                    ),
                    _ModeChip(
                      label: 'Pinned',
                      selected: searchState.mode == SearchMode.pinned,
                      onTap: () => ref
                          .read(searchControllerProvider.notifier)
                          .setMode(SearchMode.pinned),
                    ),
                    _ModeChip(
                      label: 'Favorites',
                      selected: searchState.mode == SearchMode.favorites,
                      onTap: () => ref
                          .read(searchControllerProvider.notifier)
                          .setMode(SearchMode.favorites),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _FilterChip(
                    label: searchState.folderId == null
                        ? 'All Folders'
                        : notesState.folderById(searchState.folderId)?.name ??
                            'Folder',
                    onTap: () =>
                        _showFolderFilterSheet(context, ref, notesState),
                  ),
                  _FilterChip(
                    label: searchState.tagLabel == null
                        ? 'All Tags'
                        : '#${searchState.tagLabel}',
                    onTap: () => _showTagFilterSheet(context, ref, notesState),
                  ),
                  _FilterChip(
                    label: searchState.sortOrder?.label ??
                        notesState.preferences.defaultSortOrder.label,
                    onTap: () => _showSortSheet(context, ref, notesState),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (topPicks.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Top Picks For You', style: AppTypography.titleMedium),
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
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final note = topPicks[index];
                      final folder = notesState.folderById(note.folderId);
                      return _TopPickCard(
                        noteTitle: note.displayTitle,
                        noteExcerpt: note.excerpt,
                        folderLabel: folder?.displayName ?? 'Unsorted',
                        isFavorite: note.isFavorite,
                        onTap: () {
                          if (searchState.query.trim().isNotEmpty) {
                            ref
                                .read(notesControllerProvider.notifier)
                                .saveRecentSearch(searchState.query);
                          }
                          context.push(
                            RouteNames.editor,
                            extra: <String, dynamic>{'noteId': note.id},
                          );
                        },
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.md),
                    itemCount: topPicks.length,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
              Row(
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
              ),
              const SizedBox(height: AppSpacing.md),
              if (results.isEmpty)
                AppEmptyState(
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
                )
              else
                for (final note in results)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.noteCardGap),
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
                  ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load search.',
            style: AppTypography.bodyLarge,
          ),
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context, WidgetRef ref, dynamic notesState) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandPrimary : palette.surfacePrimary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : palette.borderPrimary,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color:
                  selected ? context.colors.onPrimary : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: palette.borderPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
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
    required this.isFavorite,
    required this.onTap,
  });

  final String noteTitle;
  final String noteExcerpt;
  final String folderLabel;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          boxShadow: AppShadows.softCard,
          gradient: const LinearGradient(
            colors: [Color(0xFFF5F0FF), Color(0xFFFFF5FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isFavorite ? Icons.favorite_rounded : Icons.auto_awesome_rounded,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              noteTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              noteExcerpt,
              maxLines: 3,
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
