import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  void _showThemeModeSheet(
    BuildContext context,
    WidgetRef ref,
    AppPreferencesModel preferences,
  ) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surfacePrimary,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme mode', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                for (final option in AppThemePreference.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option.label),
                    trailing: preferences.themePreference == option
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.brandPrimary)
                        : null,
                    onTap: () {
                      ref
                          .read(notesControllerProvider.notifier)
                          .updatePreferences(
                            preferences.copyWith(themePreference: option),
                          );
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

  void _showSortOrderSheet(
    BuildContext context,
    WidgetRef ref,
    AppPreferencesModel preferences,
  ) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surfacePrimary,
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
                    onTap: () {
                      ref
                          .read(notesControllerProvider.notifier)
                          .updatePreferences(
                            preferences.copyWith(defaultSortOrder: order),
                          );
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

  void _showPreviewLinesSheet(
    BuildContext context,
    WidgetRef ref,
    AppPreferencesModel preferences,
  ) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surfacePrimary,
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
                    onTap: () {
                      ref
                          .read(notesControllerProvider.notifier)
                          .updatePreferences(
                            preferences.copyWith(previewLines: value),
                          );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        title: const Text('Theme settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
      ),
      body: SafeArea(
        child: notesAsync.when(
          data: (notesState) {
            final preferences = notesState.preferences;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              children: [
                Text('Theme & Preferences', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: palette.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.formCard),
                    border: Border.all(color: palette.borderSoft, width: 1.5),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Column(
                    children: [
                      _SettingsActionTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Theme mode',
                        subtitle: 'System, Light, or Dark appearance',
                        trailingText: preferences.themePreference.label,
                        onTap: () =>
                            _showThemeModeSheet(context, ref, preferences),
                      ),
                      Divider(
                          height: 1,
                          indent: 68,
                          endIndent: 16,
                          color: palette.borderSoft),
                      _SettingsActionTile(
                        icon: Icons.sort_rounded,
                        title: 'Default sort',
                        subtitle: 'Sort order for notes in lists',
                        trailingText: preferences.defaultSortOrder.label,
                        onTap: () =>
                            _showSortOrderSheet(context, ref, preferences),
                      ),
                      Divider(
                          height: 1,
                          indent: 68,
                          endIndent: 16,
                          color: palette.borderSoft),
                      _SettingsActionTile(
                        icon: Icons.short_text_rounded,
                        title: 'Preview lines',
                        subtitle: 'Number of text lines shown on card',
                        trailingText:
                            '${preferences.previewLines} ${preferences.previewLines == 1 ? 'line' : 'lines'}',
                        onTap: () =>
                            _showPreviewLinesSheet(context, ref, preferences),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const AppLoadingState(
            title: 'Loading appearance',
            message: 'Preparing theme and writing preferences.',
          ),
          error: (error, _) => AppErrorState(
            title: 'Unable to load theme settings',
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () async {
              await ref.read(notesControllerProvider.notifier).refresh();
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.surfaceAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: AppColors.brandPrimary,
                size: 22,
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
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 118),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      trailingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
