import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../onboarding/data/models/onboarding_profile.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../../../../core/constants/storage_keys.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    return sharedPrefs.getString(StorageKeys.lockPinHash) != null;
  }

  void _showComingSoonSnackBar(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;
    final syncEnabled = AppEnv.enableExperimentalSync;
    final onboardingProfile = ref.watch(onboardingControllerProvider).valueOrNull;
    final authSession =
        syncEnabled ? ref.watch(currentAuthSessionProvider) : null;

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
              // Custom Header to match visual specification (Title, Subtitle, Bell Trailing)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        'Manage your account and preferences.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.surfacePrimary,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.softCard,
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        Icon(Icons.notifications_none_rounded, color: palette.textPrimary),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brandLavender,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // User Identity Profile Card
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
                            image: authSession?.photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(authSession!.photoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: authSession?.photoUrl == null
                              ? Text(
                                  authSession?.initials ?? 'G',
                                  style: AppTypography.titleLarge.copyWith(
                                    color: AppColors.surfaceWhite,
                                    fontSize: 24,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWhite,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.borderPrimary),
                              boxShadow: AppShadows.softCard,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 14,
                              color: AppColors.brandPrimary,
                            ),
                          ),
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
                                authSession?.displayName ?? onboardingProfile?.workspaceName ?? 'Guest User',
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
                            authSession?.email ?? 'local-workspace@thinknote.app',
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
                              borderRadius: BorderRadius.circular(AppRadius.pill),
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
                  const Divider(height: 1, indent: 68, endIndent: 16),
                  _SettingsTile(
                    icon: Icons.text_fields_rounded,
                    iconColor: AppColors.brandPrimary,
                    iconBgColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                    title: 'Font & Text Size',
                    subtitle: 'Customize how your notes look',
                    trailingText: 'Medium',
                    onTap: () => _showComingSoonSnackBar(context, 'Font & Text Size'),
                  ),
                ],
              ),

              // Account & Data Settings Group
              _SectionHeader('Account & Data'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.cloud_queue_outlined,
                    iconColor: AppColors.brandPrimary,
                    iconBgColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                    title: 'Sync & Backup',
                    subtitle: 'Keep your notes safe and in sync',
                    trailing: authSession == null
                        ? const Text('Off')
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                              const SizedBox(width: 4),
                              Text('Synced', style: TextStyle(color: palette.textSecondary)),
                            ],
                          ),
                    onTap: authSession == null
                        ? () async {
                            final sharedPrefs = ref.read(sharedPreferencesProvider);
                            await sharedPrefs.setBool('is_guest_mode', false);
                            if (!context.mounted) return;
                            context.push(RouteNames.auth);
                          }
                        : () => _syncNow(context, ref),
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
                    title: 'Lock Notes',
                    subtitle: 'Protect your notes with a passcode',
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

              // Preferences Settings Group
              _SectionHeader('Preferences'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    iconColor: Colors.amber,
                    iconBgColor: Colors.amber.withValues(alpha: 0.1),
                    title: 'Notifications',
                    subtitle: 'Manage reminders and updates',
                    trailingText: onboardingProfile?.wantsNotifications == true ? 'On' : 'Off',
                    onTap: () => context.push(RouteNames.notificationSettings),
                  ),
                  const Divider(height: 1, indent: 68, endIndent: 16),
                  _SettingsTile(
                    icon: Icons.schedule_rounded,
                    iconColor: Colors.pink,
                    iconBgColor: Colors.pink.withValues(alpha: 0.1),
                    title: 'Reminder Defaults',
                    subtitle: 'Set default time and repeat',
                    onTap: () => _showComingSoonSnackBar(context, 'Reminder Defaults'),
                  ),
                  if (authSession != null) ...[
                    const Divider(height: 1, indent: 68, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.textDanger,
                      iconBgColor: AppColors.textDanger.withValues(alpha: 0.1),
                      title: 'Log Out',
                      subtitle: 'Sign out from your account',
                      onTap: () => _signOut(context, ref),
                    ),
                  ],
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
