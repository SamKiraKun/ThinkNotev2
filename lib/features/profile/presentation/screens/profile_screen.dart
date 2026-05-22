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
import '../../../../shared/widgets/app_header.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;

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
                title: 'Settings',
                subtitle: 'Manage offline-first preferences and sync readiness.',
                trailing: HeaderActionButton(
                  icon: Icons.cloud_sync_outlined,
                  onPressed: () => _showSnack(
                    context,
                    'Cloud sync is prepared in code and requires Firebase/Turso configuration.',
                  ),
                ),
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
                        'N',
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
                          Text('Local Workspace',
                              style: AppTypography.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Notes work offline first and are ready for authenticated cloud sync.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                    subtitle: 'Manage local reminder preferences',
                    onTap: () => context.push(RouteNames.notificationSettings),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Lock notes',
                    subtitle: 'Set a local passcode hash for protected access',
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
                    subtitle: 'Copy or restore a validated JSON backup',
                    onTap: () => context.push(RouteNames.importExport),
                  ),
                  _SettingsTile(
                    icon: Icons.cloud_queue_rounded,
                    title: 'Sync storage',
                    subtitle: 'Local SQLite database with pending sync metadata',
                    trailing: Text(
                      'Offline-first',
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    onTap: () {},
                  ),
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
                children: const [
                  _StaticTile(
                    icon: Icons.cloud_done_outlined,
                    title: 'Offline-first sync model',
                    subtitle:
                        'Create and edit locally first; sync runs after authenticated cloud setup.',
                  ),
                  _StaticTile(
                    icon: Icons.wifi_off_rounded,
                    title: 'Offline-first',
                    subtitle:
                        'Search, sorting, folders, archive, and trash work without internet.',
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
                          : AppColors.textPrimary,
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
