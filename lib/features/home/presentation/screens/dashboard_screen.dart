import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
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
import '../../../sync/presentation/controllers/sync_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final onboardingProfile =
        ref.watch(onboardingControllerProvider).valueOrNull ??
            OnboardingProfile.initial();
    final syncEnabled = AppEnv.enableExperimentalSync;
    final authSession =
        syncEnabled ? ref.watch(currentAuthSessionProvider) : null;
    final syncState = ref.watch(syncControllerProvider);

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

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              28,
              AppSpacing.xxl,
              AppSpacing.bottomNavReserved,
            ),
            children: [
              AppHeader(
                title: 'Dashboard',
                subtitle: onboardingProfile.workspaceFocus.dashboardMessage,
                leading: HeaderAvatar(
                  label: authSession?.initials ?? onboardingProfile.initials,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _WorkspaceHero(
                workspaceName: onboardingProfile.effectiveWorkspaceName,
                workspaceFocus: onboardingProfile.workspaceFocus,
                ownerLabel: authSession?.displayName ??
                    authSession?.email ??
                    'Private workspace',
                syncState: syncState,
                syncEnabled: syncEnabled,
                onCreateTap: () => context.push(RouteNames.editor),
                onSearchTap: () =>
                    ref.read(shellTabProvider.notifier).state = ShellTab.search,
                onWorkspaceTap: () => ref.read(shellTabProvider.notifier).state =
                    ShellTab.folders,
              ),
              if (syncEnabled &&
                  authSession != null &&
                  !authSession.isEmailVerified) ...[
                const SizedBox(height: AppSpacing.xl),
                _VerificationCard(
                  email: authSession.email,
                  onResend: () => _resendVerification(context, ref),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _StatsGrid(
                activeNotes: activeNotes.length,
                folders: notesState.folders.length,
                favorites: notesState.favoriteNotes.length,
                archived: notesState.archivedNotes.length,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Quick actions', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Capture',
                      subtitle: 'Open a fresh note instantly',
                      onTap: () => context.push(RouteNames.editor),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.search_rounded,
                      title: 'Search',
                      subtitle: 'Jump into notes, tags, and folders',
                      onTap: () =>
                          ref.read(shellTabProvider.notifier).state = ShellTab.search,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.folder_open_rounded,
                      title: 'Workspace',
                      subtitle: 'Organize folders, tags, and collections',
                      onTap: () => ref.read(shellTabProvider.notifier).state =
                          ShellTab.folders,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.archive_outlined,
                      title: 'Archive',
                      subtitle: 'Review stored-away notes',
                      onTap: () => context.push(RouteNames.archive),
                    ),
                  ),
                ],
              ),
              if (folderHighlights.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Workspace collections', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 148,
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
                      extra: <String, dynamic>{'noteId': note.id},
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
              const SizedBox(height: AppSpacing.xxl),
              if (recentNotes.isEmpty)
                AppEmptyState(
                  icon: Icons.edit_note_rounded,
                  title: 'Your workspace is ready for its first note',
                  message:
                      'Use quick capture to create the first note, then the dashboard will keep recent work, favorites, and collections visible here.',
                  actionLabel: 'Create your first note',
                  onAction: () => context.push(RouteNames.editor),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent work', style: AppTypography.titleMedium),
                    TextButton(
                      onPressed: () =>
                          ref.read(shellTabProvider.notifier).state = ShellTab.search,
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
                      extra: <String, dynamic>{'noteId': note.id},
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
              ],
            ],
          );
        },
        loading: () => const _DashboardLoadingState(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Unable to load dashboard', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error.toString().replaceFirst('Exception: ', ''),
                  style: AppTypography.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => ref.invalidate(notesControllerProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
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

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.workspaceName,
    required this.workspaceFocus,
    required this.ownerLabel,
    required this.syncState,
    required this.syncEnabled,
    required this.onCreateTap,
    required this.onSearchTap,
    required this.onWorkspaceTap,
  });

  final String workspaceName;
  final WorkspaceFocus workspaceFocus;
  final String ownerLabel;
  final SyncState syncState;
  final bool syncEnabled;
  final VoidCallback onCreateTap;
  final VoidCallback onSearchTap;
  final VoidCallback onWorkspaceTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppGradients.pinnedCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(
            label: syncEnabled
                ? (syncState.isSyncing
                    ? 'Sync in progress'
                    : syncState.lastError == null
                        ? 'Cloud workspace online'
                        : 'Sync attention needed')
                : 'Device-first workspace',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(workspaceName, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            workspaceFocus.headline,
            style: AppTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  ownerLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _syncSummary(syncEnabled, syncState),
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              FilledButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New note'),
              ),
              OutlinedButton.icon(
                onPressed: onSearchTap,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search'),
              ),
              OutlinedButton.icon(
                onPressed: onWorkspaceTap,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Workspace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _syncSummary(bool syncEnabled, SyncState syncState) {
    if (!syncEnabled) {
      return 'All notes stay local on this device and remain available offline.';
    }
    if (syncState.isSyncing) {
      return 'Pushing local changes and checking for updates now.';
    }
    if (syncState.lastError != null && syncState.nextRetryAt != null) {
      return 'Retry scheduled ${DateFormatter.formatRelative(syncState.nextRetryAt!)}.';
    }
    if (syncState.lastSyncedAt != null) {
      return 'Last synced ${DateFormatter.formatRelative(syncState.lastSyncedAt!)}.';
    }
    return 'Cloud sync is ready for your first connected session.';
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
  });

  final int activeNotes;
  final int folders;
  final int favorites;
  final int archived;

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
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                label: 'Folders',
                value: '$folders',
                icon: Icons.folder_outlined,
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
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricTile(
                label: 'Archived',
                value: '$archived',
                icon: Icons.archive_outlined,
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
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brandPrimary),
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
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brandPrimary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
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
          const SizedBox(height: AppSpacing.lg),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.brandPrimary,
          fontWeight: FontWeight.w700,
        ),
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