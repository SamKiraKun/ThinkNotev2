import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_formatter.dart';
import '../../features/sync/presentation/controllers/sync_controller.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.brandStyle = false,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool brandStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final syncEnabled = AppEnv.enableExperimentalSync;

    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && syncEnabled) {
      final syncState = ref.watch(syncControllerProvider);
      effectiveTrailing = _SyncHeaderButton(syncState: syncState);
    }

    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.lg),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: brandStyle
                    ? AppTypography.brandLogo
                        .copyWith(fontSize: 30, height: 1.1)
                    : AppTypography.headline.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (effectiveTrailing != null) effectiveTrailing,
      ],
    );
  }
}

class _SyncHeaderButton extends ConsumerWidget {
  const _SyncHeaderButton({required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    IconData icon;
    Color iconColor;
    bool isSpinning = false;

    if (syncState.isSyncing) {
      icon = Icons.sync_rounded;
      iconColor = AppColors.brandPrimary;
      isSpinning = true;
    } else if (syncState.lastError != null) {
      icon = Icons.cloud_off_rounded;
      iconColor = AppColors.textDanger;
    } else if (syncState.lastSyncedAt != null) {
      icon = Icons.cloud_done_rounded;
      iconColor = const Color(0xFF10B981); // Premium green
    } else {
      icon = Icons.cloud_queue_rounded;
      iconColor = palette.textSecondary;
    }

    Widget iconWidget = Icon(icon, color: iconColor);
    if (isSpinning) {
      iconWidget = RotationTransition(
        turns: const AlwaysStoppedAnimation(0.25),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(seconds: 2),
          builder: (context, value, child) {
            return RotationTransition(
              turns: AlwaysStoppedAnimation(value),
              child: child,
            );
          },
          child: Icon(icon, color: iconColor),
        ),
      );
    }

    return IconButton(
      onPressed: () => _showSyncDetailsSheet(context, ref),
      style: IconButton.styleFrom(
        backgroundColor: palette.surfacePrimary,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(color: palette.borderSoft),
        ),
        shadowColor: AppColors.shadowSoft,
        elevation: 1,
      ),
      icon: iconWidget,
    );
  }

  void _showSyncDetailsSheet(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surfacePrimary,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final syncState = ref.watch(syncControllerProvider);

            String statusTitle;
            String statusDesc;
            IconData statusIcon;
            Color statusColor;

            if (syncState.isSyncing) {
              statusTitle = 'Synchronizing Workspace';
              statusDesc = 'Pushing local note edits and fetching remote modifications...';
              statusIcon = Icons.sync_rounded;
              statusColor = AppColors.brandPrimary;
            } else if (syncState.lastError != null) {
              statusTitle = 'Sync Attention Required';
              statusDesc = 'Last attempt failed: ${syncState.lastError}';
              statusIcon = Icons.warning_amber_rounded;
              statusColor = AppColors.textDanger;
            } else if (syncState.lastSyncedAt != null) {
              statusTitle = 'Cloud Workspace Online';
              statusDesc = 'All local changes are fully synced to the secure server.';
              statusIcon = Icons.cloud_done_rounded;
              statusColor = const Color(0xFF10B981);
            } else {
              statusTitle = 'Cloud Sync Ready';
              statusDesc = 'Sign in is completed. Your cloud sync workspace is preparing.';
              statusIcon = Icons.cloud_queue_rounded;
              statusColor = palette.textSecondary;
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  0,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(statusIcon, color: statusColor, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusTitle,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                statusDesc,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(color: AppColors.formDivider),
                    const SizedBox(height: AppSpacing.md),
                    _DetailsRow(
                      label: 'Last Successful Sync',
                      value: syncState.lastSyncedAt != null
                          ? DateFormatter.formatRelative(syncState.lastSyncedAt!)
                          : 'Never',
                    ),
                    if (syncState.nextRetryAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _DetailsRow(
                        label: 'Auto-Retry Scheduled',
                        value: DateFormatter.formatRelative(syncState.nextRetryAt!),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _DetailsRow(
                      label: 'Connection Security',
                      value: 'SSL HTTPS Encrypted',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      decoration: BoxDecoration(
                        gradient: syncState.isSyncing
                            ? null
                            : AppGradients.authPrimaryButton,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        boxShadow: syncState.isSyncing ? null : AppShadows.floatingCard,
                      ),
                      child: FilledButton(
                        onPressed: syncState.isSyncing
                            ? null
                            : () async {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Starting manual workspace sync...'),
                                  ),
                                );
                                await ref
                                    .read(syncControllerProvider.notifier)
                                    .syncNow(forceFullPull: true);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        child: Text(
                          syncState.isSyncing ? 'Syncing...' : 'Sync Now',
                          style: AppTypography.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
        ),
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class HeaderAvatar extends StatelessWidget {
  const HeaderAvatar({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandLavender,
        boxShadow: AppShadows.softCard,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.titleMedium.copyWith(
          color: context.colors.onPrimary,
        ),
      ),
    );
  }
}

class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: palette.surfacePrimary,
        foregroundColor: context.colors.onSurface,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        shadowColor: AppColors.shadowSoft,
        elevation: 0,
      ),
      icon: Icon(icon),
    );
  }
}
