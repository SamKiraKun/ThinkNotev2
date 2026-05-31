import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/security/app_passcode_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/entities/authenticated_account.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../onboarding/data/models/onboarding_profile.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _displayNameFor(
    AuthenticatedAccount? account,
    AuthSession? authSession,
  ) {
    final accountName = account?.displayName?.trim();
    if (accountName != null && accountName.isNotEmpty) {
      return accountName;
    }

    final authName = authSession?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }

    final email = account?.email ?? authSession?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'ThinkNote user';
  }

  String _emailFor(
    AuthenticatedAccount? account,
    AuthSession? authSession,
  ) {
    return account?.email ?? authSession?.email ?? 'Signed in with Firebase';
  }

  String _focusBioText(WorkspaceFocus? focus) {
    if (focus == null) return '💜 Dreamer • Planner • Creator';
    switch (focus) {
      case WorkspaceFocus.capture:
        return '⚡ Capture • Speed • Ideas';
      case WorkspaceFocus.planning:
        return '💜 Dreamer • Planner • Creator';
      case WorkspaceFocus.research:
        return '📚 Research • Learn • Analyze';
      case WorkspaceFocus.journal:
        return '✍️ Reflection • Mindful • Daily';
    }
  }

  bool _isNotesLockOn(WidgetRef ref) {
    return ref.read(appPasscodeStoreProvider).hasConfiguredPasscode();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final syncState = ref.watch(syncControllerProvider);
    final palette = context.palette;
    final onboardingProfile =
        ref.watch(onboardingControllerProvider).valueOrNull;
    final authSession = ref.watch(currentAuthSessionProvider);
    final authenticatedAccount =
        ref.watch(authenticatedAccountProvider).valueOrNull;
    final displayName = _displayNameFor(authenticatedAccount, authSession);
    final email = _emailFor(authenticatedAccount, authSession);

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
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: AppTypography.headlinePrimary.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Manage your authenticated account and app preferences.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
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
                    Stack(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.brandLavender,
                            image: (authenticatedAccount?.avatarUrl ??
                                        authSession?.photoUrl) !=
                                    null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      authenticatedAccount?.avatarUrl ??
                                          authSession!.photoUrl!,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: (authenticatedAccount?.avatarUrl ??
                                      authSession?.photoUrl) ==
                                  null
                              ? Text(
                                  authSession?.initials ??
                                      displayName.characters.first
                                          .toUpperCase(),
                                  style: AppTypography.titleLarge.copyWith(
                                    color: AppColors.surfaceWhite,
                                    fontSize: 24,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayName,
                                style: AppTypography.titleMedium,
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.brandLavender,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            email,
                            style: AppTypography.bodyMedium.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceAccent,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              _focusBioText(onboardingProfile?.workspaceFocus),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.textTertiary,
                    ),
                  ],
                ),
              ),

              // Appearance Settings Group
              _SectionHeader('Appearance'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    iconColor: AppColors.brandPrimary,
                    iconBgColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                    title: 'Theme',
                    subtitle: 'Choose your preferred theme',
                    trailingText: preferences.themePreference.label,
                    onTap: () => context.push(RouteNames.themeSettings),
                  ),
                ],
              ),

              _SectionHeader('Account & Data'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.cloud_queue_outlined,
                    iconColor: AppColors.brandPrimary,
                    iconBgColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                    title: 'Sync & Backup',
                    subtitle: 'Check sync status for your signed-in account',
                    trailing: syncState.isSyncing
                        ? Text(
                            'Syncing',
                            style: AppTypography.bodyMedium.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : syncState.lastError == null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Synced',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.textDanger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    describeSyncErrorType(
                                      syncState.lastErrorType,
                                    ),
                                    style:
                                        TextStyle(color: palette.textSecondary),
                                  ),
                                ],
                              ),
                    onTap: () => _syncNow(context, ref),
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16),
                  _SettingsTile(
                    icon: Icons.history_rounded,
                    iconColor: AppColors.brandPrimary,
                    iconBgColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                    title: 'Import & Export',
                    subtitle: 'Move or download your notes',
                    onTap: () => context.push(RouteNames.importExport),
                  ),
                ],
              ),

              // Security & Privacy Settings Group
              _SectionHeader('Security & Privacy'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: AppColors.brandPrimary,
                    iconBgColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                    title: 'App Passcode',
                    subtitle:
                        'Require a passcode before ThinkNote opens on this device',
                    trailingText: _isNotesLockOn(ref) ? 'On' : 'Off',
                    onTap: () => context.push(RouteNames.lockNotes),
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.brandPrimary,
                    iconBgColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                    title: 'Privacy',
                    subtitle: 'Manage data and privacy preferences',
                    onTap: () => context.push(RouteNames.privacy),
                  ),
                ],
              ),

              if (authSession != null) ...[
                _SectionHeader('Account'),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.textDanger,
                      iconBgColor: AppColors.textDanger.withValues(alpha: 0.1),
                      title: 'Log Out',
                      subtitle: 'Sign out from your account',
                      onTap: () => _signOut(context, ref),
                    ),
                    const Divider(height: 1, indent: 68, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: AppColors.textDanger,
                      iconBgColor: AppColors.textDanger.withValues(alpha: 0.1),
                      title: 'Delete account',
                      subtitle:
                          'Permanently remove your account and synced data',
                      onTap: () => _confirmDeleteAccount(context, ref),
                    ),
                  ],
                ),
              ],
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
        : '${describeSyncErrorType(syncState.lastErrorType)}: ${syncState.lastError}';
    if (!context.mounted) {
      return;
    }
    _showSnack(context, message);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
    ref.invalidate(appStartupSnapshotProvider);
    if (!context.mounted) {
      return;
    }
    _showSnack(context, 'Signed out.');
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your ThinkNote account and synced notes. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(authControllerProvider.notifier).deleteAccount();
    ref.invalidate(appStartupSnapshotProvider);
    if (!context.mounted) {
      return;
    }
    _showSnack(context, 'Account deleted.');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxl,
        bottom: AppSpacing.md,
      ),
      child: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
    this.trailingText,
    this.iconColor,
    this.iconBgColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? trailingText;
  final Color? iconColor;
  final Color? iconBgColor;

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
                color: iconBgColor ?? palette.surfaceAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: iconColor ?? AppColors.brandPrimary,
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
                      color: palette.textPrimary,
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
            if (trailing != null)
              trailing!
            else if (trailingText != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailingText!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textTertiary,
                  ),
                ],
              )
            else
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
