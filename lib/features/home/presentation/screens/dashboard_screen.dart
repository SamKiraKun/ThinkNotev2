import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_names.dart';
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
import '../../../auth/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../folders/presentation/widgets/folder_visuals.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../notes/presentation/widgets/note_card.dart';
import '../../../onboarding/data/models/onboarding_profile.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../search/presentation/controllers/search_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final onboardingProfile =
        ref.watch(onboardingControllerProvider).valueOrNull ??
            OnboardingProfile.initial();
    final authSession = ref.watch(currentAuthSessionProvider);

    return SafeArea(
      bottom: false,
      child: notesAsync.when(
        data: (notesState) {
          final activeNotes = notesState.activeNotes;
          final topPicks = notesState.topPicks(limit: 4);
          final recentNotes = activeNotes.take(5).toList(growable: false);
          final folderHighlights = notesState.folderSummaries
              .where((summary) => summary.noteCount > 0)
              .take(5)
              .toList(growable: false);
          final isEmptyWorkspace = activeNotes.isEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              28,
              AppSpacing.xxl,
              AppSpacing.bottomNavReserved,
            ),
            children: [
              AppHeader(
                title: isEmptyWorkspace ? AppConstants.appName : 'Dashboard',
                subtitle: isEmptyWorkspace
                    ? 'Start with a note. Everything syncs to your signed-in account.'
                    : onboardingProfile.workspaceFocus.dashboardMessage,
                leading: HeaderAvatar(
                  label: authSession?.initials ?? onboardingProfile.initials,
                ),
                brandStyle: isEmptyWorkspace,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (isEmptyWorkspace)
                AppEmptyState(
                  icon: Icons.edit_note_rounded,
                  eyebrow: 'Ready to write',
                  title: 'No notes yet',
                  message:
                      'Create your first note in one tap. Organize it later with folders, tags, and search when your workspace grows.',
                  supportingNote:
                      'Your notes stay tied to your authenticated account.',
                  highlights: const <String>[
                    'Secure account',
                    'Folders later',
                    'Search anytime',
                  ],
                  actionLabel: 'Create your first note',
                  onAction: () => context.push(RouteNames.editor),
                )
              else ...[
                // Recent work section at the very top of Dashboard scrollview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent work', style: AppTypography.titleMedium),
                    TextButton(
                      onPressed: () => ref
                          .read(shellTabProvider.notifier)
                          .state = ShellTab.search,
                      child: const Text('Open search'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (final note in recentNotes) ...[
                  NoteCard(
                    note: note,
                    folder: notesState.folderById(note.folderId),
                    subtitle:
                        'Updated ${DateFormatter.formatRelative(note.updatedAt)}',
                    previewLines: notesState.preferences.previewLines,
                    onTap: () => context.push(
                      RouteNames.editor,
                      extra: <String, dynamic>{
                        'noteId': note.id,
                        'initialNote': note,
                      },
                    ),
                    onPinTap: () => ref
                        .read(notesControllerProvider.notifier)
                        .togglePin(note.id),
                    onFavoriteTap: () => ref
                        .read(notesControllerProvider.notifier)
                        .toggleFavorite(note.id),
                  ),
                  if (note != recentNotes.last)
                    const SizedBox(height: AppSpacing.md),
                ],

                if (authSession != null && !authSession.isEmailVerified) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  _VerificationCard(
                    email: authSession.email,
                    onResend: () => _resendVerification(context, ref),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
                _StatsGrid(
                  activeNotes: activeNotes.length,
                  folders: notesState.folders.length,
                  favorites: notesState.favoriteNotes.length,
                  archived: notesState.archivedNotes.length,
                  onActiveNotesTap: () {
                    ref
                        .read(searchControllerProvider.notifier)
                        .setMode(SearchMode.notes);
                    ref.read(shellTabProvider.notifier).state = ShellTab.search;
                  },
                  onFoldersTap: () {
                    ref.read(shellTabProvider.notifier).state =
                        ShellTab.folders;
                  },
                  onFavoritesTap: () {
                    ref
                        .read(searchControllerProvider.notifier)
                        .setMode(SearchMode.favorites);
                    ref.read(shellTabProvider.notifier).state = ShellTab.search;
                  },
                  onArchivedTap: () {
                    context.push(RouteNames.archive);
                  },
                ),

                if (folderHighlights.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Folders',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final summary = folderHighlights[index];
                        return _CollectionCard(
                          label: summary.folder.displayName,
                          noteCount: summary.noteCount,
                          colorKey: summary.folder.colorKey,
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemCount: folderHighlights.length,
                    ),
                  ),
                ],
                if (topPicks.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Top picks', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  for (final note in topPicks) ...[
                    NoteCard(
                      note: note,
                      folder: notesState.folderById(note.folderId),
                      subtitle:
                          'Updated ${DateFormatter.formatRelative(note.updatedAt)}',
                      previewLines: notesState.preferences.previewLines,
                      onTap: () => context.push(
                        RouteNames.editor,
                        extra: <String, dynamic>{
                          'noteId': note.id,
                          'initialNote': note,
                        },
                      ),
                      onPinTap: () => ref
                          .read(notesControllerProvider.notifier)
                          .togglePin(note.id),
                      onFavoriteTap: () => ref
                          .read(notesControllerProvider.notifier)
                          .toggleFavorite(note.id),
                    ),
                    if (note != topPicks.last)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ],
            ],
          );
        },
        loading: () => const _DashboardLoadingState(),
        error: (error, _) => _DashboardErrorState(
          message: _dashboardErrorMessage(error),
        ),
      ),
    );
  }

  Future<void> _resendVerification(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).sendEmailVerification();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent.')),
    );
  }
}

String _dashboardErrorMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  final normalized = message.toLowerCase();
  if (normalized.contains('sqlite') ||
      normalized.contains('database') ||
      normalized.contains('transaction')) {
    return 'Your local notes could not be reopened yet. Try loading the dashboard again.';
  }

  return message;
}

class _DashboardErrorState extends ConsumerStatefulWidget {
  const _DashboardErrorState({required this.message});

  final String message;

  @override
  ConsumerState<_DashboardErrorState> createState() =>
      _DashboardErrorStateState();
}

class _DashboardErrorStateState extends ConsumerState<_DashboardErrorState> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying) {
      return;
    }

    setState(() {
      _isRetrying = true;
    });

    try {
      await ref.read(notesControllerProvider.notifier).refresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Unable to load dashboard', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.message,
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isRetrying ? null : _retry,
              child: Text(_isRetrying ? 'Retrying...' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.email,
    required this.onResend,
  });

  final String? email;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        border: Border.all(color: palette.borderPrimary),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verify your email', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email == null
                      ? 'Confirm your account email to tighten account recovery and trust signals.'
                      : 'Confirm $email to strengthen account recovery and account trust signals.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: onResend,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Resend verification'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.activeNotes,
    required this.folders,
    required this.favorites,
    required this.archived,
    required this.onActiveNotesTap,
    required this.onFoldersTap,
    required this.onFavoritesTap,
    required this.onArchivedTap,
  });

  final int activeNotes;
  final int folders;
  final int favorites;
  final int archived;
  final VoidCallback onActiveNotesTap;
  final VoidCallback onFoldersTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onArchivedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Active notes',
                value: '$activeNotes',
                icon: Icons.description_outlined,
                onTap: onActiveNotesTap,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                label: 'Folders',
                value: '$folders',
                icon: Icons.folder_outlined,
                onTap: onFoldersTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Favorites',
                value: '$favorites',
                icon: Icons.star_border_rounded,
                onTap: onFavoritesTap,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                label: 'Archived',
                value: '$archived',
                icon: Icons.archive_outlined,
                onTap: onArchivedTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        border: Border.all(color: palette.borderSoft),
        boxShadow: AppShadows.softCard,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppColors.brandPrimary, size: 20),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(value, style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.label,
    required this.noteCount,
    required this.colorKey,
  });

  final String label;
  final int noteCount;
  final String colorKey;

  @override
  Widget build(BuildContext context) {
    final visuals = folderVisualsFor(colorKey);
    final palette = context.palette;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        border: Border.all(color: palette.borderSoft),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: visuals.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(visuals.icon, color: visuals.accentColor),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: AppTypography.titleSmall),
          const Spacer(),
          Text(
            '$noteCount notes',
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        28,
        AppSpacing.xxl,
        AppSpacing.bottomNavReserved,
      ),
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: AppGradients.pinnedCard,
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ],
    );
  }
}
