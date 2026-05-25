import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../controllers/onboarding_controller.dart';

class AppLaunchScreen extends ConsumerStatefulWidget {
  const AppLaunchScreen({super.key});

  @override
  ConsumerState<AppLaunchScreen> createState() => _AppLaunchScreenState();
}

class _AppLaunchScreenState extends ConsumerState<AppLaunchScreen> {
  bool _showProgress = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showProgress = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final startup = ref.watch(appStartupSnapshotProvider);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: startup.when(
                loading: () => _showProgress
                    ? _LaunchBody(
                        title: 'Preparing your workspace',
                        subtitle: AppEnv.enableExperimentalSync
                            ? 'Restoring your setup, account access, and note library before the dashboard opens.'
                            : 'Restoring your setup and local note library before the dashboard opens.',
                        showProgress: true,
                        steps: <_LaunchStepData>[
                          const _LaunchStepData(
                            label: 'Validate app configuration',
                            state: _LaunchStepState.complete,
                          ),
                          const _LaunchStepData(
                            label: 'Restore onboarding and workspace profile',
                            state: _LaunchStepState.active,
                          ),
                          _LaunchStepData(
                            label: AppEnv.enableExperimentalSync
                                ? 'Resolve account session'
                                : 'Restore local workspace',
                            state: _LaunchStepState.pending,
                          ),
                          _LaunchStepData(
                            label: AppEnv.enableExperimentalSync
                                ? 'Warm note cache for sync-aware launch'
                                : 'Warm note cache for offline launch',
                            state: _LaunchStepState.pending,
                          ),
                        ],
                      )
                    : const _SplashVisual(),
                error: (error, _) => _LaunchErrorState(
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () {
                    ref.invalidate(onboardingControllerProvider);
                    ref.invalidate(notesControllerProvider);
                    ref.invalidate(appStartupSnapshotProvider);
                  },
                ),
                data: (snapshot) => _showProgress
                    ? _LaunchBody(
                        title: snapshot.onboardingProfile.hasCompletedOnboarding
                            ? 'Opening ${snapshot.onboardingProfile.effectiveWorkspaceName}'
                            : 'Setting up ThinkNote',
                        subtitle: snapshot.requiresAuthentication
                            ? 'Your workspace is ready. Sign in to reconnect cloud sync and continue.'
                            : 'Your workspace is ready. Redirecting to the dashboard now.',
                        showProgress: false,
                        steps: <_LaunchStepData>[
                          const _LaunchStepData(
                            label: 'App configuration validated',
                            state: _LaunchStepState.complete,
                          ),
                          _LaunchStepData(
                            label: snapshot.onboardingProfile.hasCompletedOnboarding
                                ? 'Workspace profile restored'
                                : 'Workspace setup ready',
                            state: _LaunchStepState.complete,
                          ),
                          _LaunchStepData(
                            label: snapshot.requiresAuthentication
                                ? 'Account sign-in required'
                                : 'Account session resolved',
                            state: snapshot.requiresAuthentication
                                ? _LaunchStepState.active
                                : _LaunchStepState.complete,
                          ),
                          const _LaunchStepData(
                            label: 'Dashboard handoff in progress',
                            state: _LaunchStepState.active,
                          ),
                        ],
                      )
                    : const _SplashVisual(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashVisual extends StatelessWidget {
  const _SplashVisual();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: AppGradients.authPrimaryButton,
              borderRadius: BorderRadius.circular(30),
              boxShadow: AppShadows.floatingCard,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: child,
            );
          },
          child: Column(
            children: [
              Text(
                'ThinkNote',
                style: AppTypography.headlinePrimary.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Capture ideas instantly.',
                style: AppTypography.tagline.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LaunchBody extends StatelessWidget {
  const _LaunchBody({
    required this.title,
    required this.subtitle,
    required this.showProgress,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final bool showProgress;
  final List<_LaunchStepData> steps;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: AppGradients.authPrimaryButton,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.floatingCard,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(title, style: AppTypography.headlinePrimary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: AppTypography.bodyLarge.copyWith(
            color: palette.textSecondary,
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
          child: Column(
            children: [
              for (final step in steps) ...[
                _LaunchStep(step: step),
                if (step != steps.last) const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
        if (showProgress) ...[
          const SizedBox(height: AppSpacing.xxl),
          const LinearProgressIndicator(minHeight: 6),
        ],
      ],
    );
  }
}

class _LaunchErrorState extends StatelessWidget {
  const _LaunchErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.textDanger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.textDanger,
            size: 36,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Launch blocked', style: AppTypography.headlinePrimary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: AppTypography.bodyLarge.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry launch'),
          ),
        ),
      ],
    );
  }
}

class _LaunchStep extends StatelessWidget {
  const _LaunchStep({required this.step});

  final _LaunchStepData step;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: switch (step.state) {
              _LaunchStepState.complete => AppColors.brandPrimary,
              _LaunchStepState.active =>
                AppColors.brandPrimary.withValues(alpha: 0.12),
              _LaunchStepState.pending => palette.surfaceSecondary,
            },
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: switch (step.state) {
            _LaunchStepState.complete => const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 18,
              ),
            _LaunchStepState.active => const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            _LaunchStepState.pending => Icon(
                Icons.more_horiz_rounded,
                color: palette.textTertiary,
                size: 18,
              ),
          },
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              step.label,
              style: AppTypography.bodyLarge.copyWith(
                color: step.state == _LaunchStepState.pending
                    ? palette.textTertiary
                    : context.colors.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _LaunchStepState { complete, active, pending }

class _LaunchStepData {
  const _LaunchStepData({
    required this.label,
    required this.state,
  });

  final String label;
  final _LaunchStepState state;
}