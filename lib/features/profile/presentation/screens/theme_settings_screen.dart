import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Theme settings')),
      body: SafeArea(
        child: notesAsync.when(
          data: (notesState) {
            final preferences = notesState.preferences;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              children: [
                Text('Appearance', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.md),
                for (final option in AppThemePreference.values)
                  _SelectableSettingTile(
                    title: option.label,
                    subtitle: _themeDescription(option),
                    selected: preferences.themePreference == option,
                    onTap: () {
                      ref
                          .read(notesControllerProvider.notifier)
                          .updatePreferences(
                            preferences.copyWith(themePreference: option),
                          );
                    },
                  ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Note cards', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.md),
                for (final count in const [1, 2, 3, 4])
                  _SelectableSettingTile(
                    title: '$count preview ${count == 1 ? 'line' : 'lines'}',
                    selected: preferences.previewLines == count,
                    onTap: () {
                      ref
                          .read(notesControllerProvider.notifier)
                          .updatePreferences(
                            preferences.copyWith(previewLines: count),
                          );
                    },
                  ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Default sort', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.md),
                for (final order in NoteSortOrder.values)
                  _SelectableSettingTile(
                    title: order.label,
                    selected: preferences.defaultSortOrder == order,
                    onTap: () {
                      ref
                          .read(notesControllerProvider.notifier)
                          .updatePreferences(
                            preferences.copyWith(defaultSortOrder: order),
                          );
                    },
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Unable to load theme settings.',
              style: AppTypography.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }

  String _themeDescription(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.system:
        return 'Follow your device appearance.';
      case AppThemePreference.light:
        return 'Use the bright ThinkNote palette.';
      case AppThemePreference.dark:
        return 'Use the low-light ThinkNote palette.';
    }
  }
}

class _SelectableSettingTile extends StatelessWidget {
  const _SelectableSettingTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.brandPrimary : palette.textTertiary,
      ),
      onTap: selected ? null : onTap,
    );
  }
}
