import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late bool _notificationsEnabled;
  late int _defaultReminderMinutes;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(sharedPreferencesProvider);
    _notificationsEnabled =
        preferences.getBool(StorageKeys.notificationsEnabled) ?? false;
    _defaultReminderMinutes =
        preferences.getInt(StorageKeys.defaultReminderMinutes) ?? 30;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Notification settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            // Header Intro Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: palette.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.formCard),
                boxShadow: AppShadows.softCard,
                border: Border.all(color: palette.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.brandPrimary,
                    size: 38,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Workspace Alerts',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Set reminders for your captures, scheduled logs, and daily write-ups. Alerts will appear as local device notifications.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Toggle Card
            Container(
              decoration: BoxDecoration(
                color: palette.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.formCard),
                boxShadow: AppShadows.softCard,
                border: Border.all(color: palette.borderSoft),
              ),
              child: SwitchListTile(
                value: _notificationsEnabled,
                title: Text(
                  'Enable local reminders',
                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Receive push reminders on scheduled notes.',
                  style: AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
                ),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.brandPrimary,
                onChanged: (value) => _setNotificationsEnabled(value),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Lead Time Section
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _notificationsEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !_notificationsEnabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default reminder lead time',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: [
                        _buildReminderTile(10, '10 minutes before', 'Quick heads-up reminder'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildReminderTile(30, '30 minutes before', 'Standard timing'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildReminderTile(60, '1 hour before', 'Prepare in advance'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildReminderTile(1440, '1 day before', 'Plan ahead of time'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Action Row
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _notificationsEnabled ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_notificationsEnabled,
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _simulateTestNotification,
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Simulate Test Reminder'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: AppColors.brandPrimary,
                        side: const BorderSide(color: AppColors.brandPrimary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTile(int option, String title, String subtitle) {
    final palette = context.palette;
    final isSelected = _defaultReminderMinutes == option;

    return InkWell(
      onTap: () => _setDefaultReminder(option),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary.withValues(alpha: 0.06) : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : palette.borderSoft,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.brandPrimary : palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.brandPrimary : palette.textPlaceholder,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(StorageKeys.notificationsEnabled, value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _setDefaultReminder(int value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setInt(StorageKeys.defaultReminderMinutes, value);
    setState(() => _defaultReminderMinutes = value);
  }

  void _simulateTestNotification() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ThinkNote Alert (Simulated)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Don\'t forget to write your logs for today!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.brandPrimary,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
