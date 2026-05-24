import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_feature_notice_screen.dart';

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
    if (!AppEnv.showPrototypeTools) {
      return const AppFeatureNoticeScreen(
        title: 'Notification settings',
        icon: Icons.notifications_off_outlined,
        headline: 'Reminders are not part of this release',
        message:
            'ThinkNote 1.0 focuses on local note capture and organization. Reminder delivery will ship only after permissions, scheduling, and background behavior are implemented end-to-end.',
      );
    }

    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Notification settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            SwitchListTile(
              value: _notificationsEnabled,
              title: const Text('Enable local reminders'),
              subtitle: const Text(
                'Stores reminder preferences locally. Scheduling remains experimental in non-production builds.',
              ),
              activeThumbColor: AppColors.brandPrimary,
              onChanged: (value) => _setNotificationsEnabled(value),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Default reminder lead time',
                style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            for (final option in const [10, 30, 60, 1440])
              _ReminderOptionTile(
                title: _formatReminderOption(option),
                selected: _defaultReminderMinutes == option,
                enabled: _notificationsEnabled,
                onTap: () => _setDefaultReminder(option),
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

  String _formatReminderOption(int minutes) {
    if (minutes == 1440) {
      return '1 day before';
    }
    if (minutes >= 60) {
      return '${minutes ~/ 60} hour before';
    }
    return '$minutes minutes before';
  }
}

class _ReminderOptionTile extends StatelessWidget {
  const _ReminderOptionTile({
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveColor =
        enabled ? palette.textSecondary : palette.textTertiary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(color: effectiveColor),
      ),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color:
            selected && enabled ? AppColors.brandPrimary : palette.textTertiary,
      ),
      onTap: !enabled || selected ? null : onTap,
    );
  }
}
