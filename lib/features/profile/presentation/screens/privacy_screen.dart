import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/auth_providers.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final syncEnabled = AppEnv.enableExperimentalSync;
    final session = syncEnabled ? ref.watch(currentAuthSessionProvider) : null;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Privacy and storage')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            _PrivacyCard(
              icon: syncEnabled
                  ? Icons.cloud_done_outlined
                  : Icons.smartphone_rounded,
              title: syncEnabled ? 'Account and sync' : 'Local-only workspace',
              message: syncEnabled
                  ? 'ThinkNote uses Firebase Authentication for account sign-in and syncs note data, folders, and tags to the ThinkNote backend for ${session?.email ?? 'your signed-in account'}.'
                  : 'ThinkNote 1.0 does not create accounts, upload notes, or sync note content to a cloud service.',
            ),
            const SizedBox(height: AppSpacing.lg),
            const _PrivacyCard(
              icon: Icons.storage_rounded,
              title: 'Device storage',
              message:
                  'Notes and their local metadata are encrypted before they are stored in the app private database on this device. Device security still matters because rooted devices, unlocked sessions, or advanced tooling can expose decrypted content while the app is running.',
            ),
            const SizedBox(height: AppSpacing.lg),
            const _PrivacyCard(
              icon: Icons.backup_outlined,
              title: 'Backup behavior',
              message:
                  'Android cloud backup and device-transfer backup are disabled for ThinkNote app data in this release.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _PrivacyCard(
              icon: Icons.analytics_outlined,
              title: 'Diagnostics and analytics',
              message: syncEnabled
                  ? 'This release uses the Firebase client SDK for authentication. Analytics and ads remain disabled unless they are added and disclosed separately.'
                  : 'This production path does not include analytics, ads, crash reporting, or a client Firebase SDK.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _PrivacyCard(
              icon: Icons.delete_outline_rounded,
              title: syncEnabled ? 'Deleting account data' : 'Deleting local data',
              message: syncEnabled
                  ? 'Use Delete account in Settings to remove your ThinkNote account and synced note data from the backend. Local cached notes for that account are cleared during deletion.'
                  : 'Use Clear all notes in Settings to remove notes from this device. Uninstalling the app also removes its local app data.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  message,
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
