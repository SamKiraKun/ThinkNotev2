import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../onboarding/data/models/onboarding_profile.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;
    final syncEnabled = AppEnv.enableExperimentalSync;
    final onboardingProfile = ref.watch(onboardingControllerProvider).valueOrNull;
    final authSession =
        syncEnabled ? ref.watch(currentAuthSessionProvider) : null;
    final syncState = ref.watch(syncControllerProvider);

    return SafeArea(
      bottom: false,
      child: notesAsync.when(
        data: (notesState) {
          final preferences = notesState.preferences;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              28,
              AppSpacing.xxl,
              AppSpacing.bottomNavReserved,
            ),
            children: [
              AppHeader(
                title: 'Profile',
                subtitle: syncEnabled
                  ? 'Manage your account, workspace identity, sync posture, and device preferences.'
                  : 'Manage your workspace identity, local notes, and device preferences.',
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: palette.surfacePrimary,
                  borderRadius: BorderRadius.circular(AppRadius.formCard),
                  boxShadow: AppShadows.softCard,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandLavender,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        authSession?.initials ?? 'G',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            onboardingProfile?.effectiveWorkspaceName ??
                                (syncEnabled
                                    ? 'Cloud workspace'
                                    : 'Local workspace'),
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            syncEnabled
                                ? (authSession == null
                                    ? '${onboardingProfile?.workspaceFocus.label ?? 'Guest workspace'} · Writing as Guest. Notes are stored locally on this device.'
                                    : '${onboardingProfile?.workspaceFocus.label ?? 'Cloud workspace'} · Notes save on this device first and sync to your account when you are online.')
                                : '${onboardingProfile?.workspaceFocus.label ?? 'Device workspace'} · Notes stay on this device and are available offline anytime.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          if (syncEnabled && authSession?.email != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              authSession!.email!,
                              style: AppTypography.bodySmall.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                          if (syncEnabled &&
                              authSession != null &&
                              !authSession.isEmailVerified) ...[
                            const SizedBox(height: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: () => _sendVerification(context, ref),
                              icon: const Icon(Icons.mark_email_read_outlined),
                              label: const Text('Resend verification email'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (syncEnabled) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Account', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.md),
                if (authSession == null)
                  _SettingsGroup(
                    children: [
                      _SettingsTile(
                        icon: Icons.login_rounded,
                        title: 'Link Cloud Account',
                        subtitle: 'Sign in or register to enable real-time cloud synchronization and backups',
                        onTap: () async {
                          final sharedPrefs = ref.read(sharedPreferencesProvider);
                          await sharedPrefs.setBool('is_guest_mode', false);
                          ref.invalidate(appStartupSnapshotProvider);
                        },
                      ),
                    ],
                  )
                else
                  _SettingsGroup(
                    children: [
                      _SettingsTile(
                        icon: Icons.cloud_sync_outlined,
                        title: 'Sync now',
                        subtitle: syncState.lastError == null
                            ? (syncState.lastSyncedAt == null
                                ? 'Push local changes and pull latest notes'
                                : 'Last sync ${syncState.lastSyncedAt}')
                            : 'Last sync failed. Tap to retry.',
                        onTap: () => _syncNow(context, ref),
                      ),
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        subtitle:
                            'Stop syncing on this device until you sign in again or switch accounts',
                        onTap: () => _signOut(context, ref),
                      ),
                      if (authSession != null && !authSession.isEmailVerified)
                        _SettingsTile(
                          icon: Icons.mark_email_read_outlined,
                          title: 'Verify email',
                          subtitle:
                              'Resend a verification email for stronger account recovery',
                          onTap: () => _sendVerification(context, ref),
                        ),
                      _SettingsTile(
                        icon: Icons.person_remove_outlined,
                        title: 'Delete account',
                        subtitle:
                            'Remove your account and synced note data from ThinkNote',
                        onTap: () => _confirmDeleteAccount(context, ref),
                        isDestructive: true,
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              Text('Preferences', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Theme mode',
                    subtitle: 'Choose the appearance for this device',
                    trailing: Text(
                      preferences.themePreference.label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    onTap: () => context.push(RouteNames.themeSettings),
                  ),
                  _SettingsTile(
                    icon: Icons.sort_rounded,
                    title: 'Default sort',
                    subtitle: 'Choose how notes are organized in lists',
                    trailing: Text(
                      preferences.defaultSortOrder.label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    onTap: () => _showSortDialog(context, ref, preferences),
                  ),
                  _SettingsTile(
                    icon: Icons.short_text_rounded,
                    title: 'Preview lines',
                    subtitle: 'Set how many lines appear in note cards',
                    trailing: Text(
                      '${preferences.previewLines}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    onTap: () => _showPreviewDialog(context, ref, preferences),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Configure note notification and task reminder alerts',
                    onTap: () =>
                        context.push(RouteNames.notificationSettings),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Lock notes',
                    subtitle: 'Secure note databases with local passcode lock',
                    onTap: () => context.push(RouteNames.lockNotes),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Data', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.archive_outlined,
                    title: 'Archive',
                    subtitle:
                        '${notesState.archivedNotes.length} archived notes',
                    onTap: () => context.push(RouteNames.archive),
                  ),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Trash',
                    subtitle:
                        '${notesState.trashedNotes.length} deleted notes waiting for action',
                    onTap: () => context.push(RouteNames.trash),
                  ),
                  _SettingsTile(
                    icon: Icons.import_export_rounded,
                    title: 'Import and export',
                    subtitle: 'Export and restore note databases via JSON files',
                    onTap: () => context.push(RouteNames.importExport),
                  ),
                  if (!syncEnabled)
                    _SettingsTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Clear all notes',
                      subtitle:
                          'Remove active and deleted notes from this device',
                      onTap: () => _confirmClearAll(context, ref),
                      isDestructive: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('About', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy and storage',
                    subtitle: syncEnabled
                        ? 'Review device storage, synced data, and deletion'
                        : 'Review what stays on this device',
                    onTap: () => context.push(RouteNames.privacy),
                  ),
                  _StaticTile(
                    icon: syncEnabled
                        ? Icons.cloud_done_outlined
                        : Icons.smartphone_rounded,
                    title: syncEnabled
                        ? 'Offline-first sync'
                        : 'Local-only release',
                    subtitle: syncEnabled
                        ? 'Notes save locally first, then sync to your account when a connection is available.'
                        : 'This release focuses on fast local notes without account, sync, or clipboard backup claims.',
                  ),
                  _StaticTile(
                    icon: Icons.wifi_off_rounded,
                    title: syncEnabled ? 'Works offline' : 'Offline-first',
                    subtitle: syncEnabled
                        ? 'Search, sorting, folders, archive, and trash continue to work without internet while pending changes wait to sync.'
                        : 'Search, sorting, folders, archive, and trash work without internet.',
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load settings.',
            style: AppTypography.bodyLarge,
          ),
        ),
      ),
    );
  }

  Future<void> _showSortDialog(
    BuildContext context,
    WidgetRef ref,
    AppPreferencesModel preferences,
  ) async {
    final selected = await showModalBottomSheet<NoteSortOrder>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Default sort', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                for (final order in NoteSortOrder.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(order.label),
                    trailing: preferences.defaultSortOrder == order
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.brandPrimary)
                        : null,
                    onTap: () => Navigator.of(context).pop(order),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await ref.read(notesControllerProvider.notifier).updatePreferences(
            preferences.copyWith(defaultSortOrder: selected),
          );
    }
  }

  Future<void> _sendVerification(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).sendEmailVerification();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent.')),
    );
  }

  Future<void> _showPreviewDialog(
    BuildContext context,
    WidgetRef ref,
    AppPreferencesModel preferences,
  ) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview lines', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                for (final value in const [1, 2, 3, 4])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$value lines'),
                    trailing: preferences.previewLines == value
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.brandPrimary)
                        : null,
                    onTap: () => Navigator.of(context).pop(value),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await ref.read(notesControllerProvider.notifier).updatePreferences(
            preferences.copyWith(previewLines: selected),
          );
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Clear all notes?',
        message:
            'This removes every note from this device, including items in Trash.',
        confirmLabel: 'Clear everything',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      await ref.read(notesControllerProvider.notifier).clearAllNotes();
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    await ref.read(syncControllerProvider.notifier).syncNow();
    final syncState = ref.read(syncControllerProvider);
    final message = syncState.lastError == null
        ? 'Sync complete.'
        : 'Sync failed: ${syncState.lastError}';
    if (!context.mounted) {
      return;
    }
    _showSnack(context, message);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.setBool('is_guest_mode', false);
    await ref.read(authControllerProvider.notifier).signOut();
    ref.invalidate(appStartupSnapshotProvider);
    if (!context.mounted) {
      return;
    }
    _showSnack(context, 'Signed out.');
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Delete account?',
        message:
            'This removes your ThinkNote account and synced note data from the backend.',
        confirmLabel: 'Delete account',
        isDestructive: true,
      ),
    );

    if (confirmed != true) {
      return;
    }

    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.setBool('is_guest_mode', false);
    await ref.read(authControllerProvider.notifier).deleteAccount();
    ref.invalidate(appStartupSnapshotProvider);
    if (!context.mounted) {
      return;
    }
    _showSnack(context, 'Account deleted.');
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDestructive
                    ? context.colors.errorContainer.withValues(alpha: 0.28)
                    : palette.surfaceAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isDestructive
                    ? AppColors.textDanger
                    : AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: isDestructive
                          ? AppColors.textDanger
                          : palette.textPrimary,
                    ),
                  ),
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
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.textTertiary,
                ),
          ],
        ),
      ),
    );
  }
}

class _StaticTile extends StatelessWidget {
  const _StaticTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.surfaceAccent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
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
        ],
      ),
    );
  }
}
