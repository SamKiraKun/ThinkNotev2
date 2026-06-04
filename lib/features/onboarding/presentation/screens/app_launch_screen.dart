import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/authenticated_api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/auth_providers.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../controllers/onboarding_controller.dart';

class AppLaunchScreen extends ConsumerWidget {
  const AppLaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final startup = ref.watch(appStartupSnapshotProvider);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _LaunchBackdrop()),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: startup.when(
                    loading: () => const _SplashVisual(),
                    error: (error, _) => _LaunchErrorState(
                      message: _describeLaunchError(error),
                      onRetry: () {
                        ref.invalidate(authenticatedAccountProvider);
                        ref.invalidate(onboardingControllerProvider);
                        ref.invalidate(notesControllerProvider);
                        ref.invalidate(appStartupSnapshotProvider);
                      },
                    ),
                    data: (_) => const _SplashVisual(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _describeLaunchError(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  return error.toString().replaceFirst('Exception: ', '');
}

class _LaunchBackdrop extends StatelessWidget {
  const _LaunchBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            top: -96,
            right: -48,
            child: _AmbientGlow(
              size: 240,
              colors: [
                Color(0x246F63FF),
                Color(0x146F63FF),
                Color(0x00FFFFFF),
              ],
            ),
          ),
          Positioned(
            top: 180,
            left: -68,
            child: _AmbientGlow(
              size: 200,
              colors: [
                Color(0x18F3A7D8),
                Color(0x106F63FF),
                Color(0x00FFFFFF),
              ],
            ),
          ),
          Positioned(
            bottom: -110,
            left: 36,
            child: _AmbientGlow(
              size: 280,
              colors: [
                Color(0x1AB69BFF),
                Color(0x126F63FF),
                Color(0x00FFFFFF),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
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
          tween: Tween<double>(begin: 0.92, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              'assets/icons/logo.png',
              width: 92,
              height: 92,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: Column(
            children: [
              Text(
                'ThinkNote',
                style: AppTypography.brandLogo.copyWith(
                  fontSize: 38,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Capture ideas instantly.',
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: palette.surfacePrimary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: palette.borderSoft),
                  boxShadow: AppShadows.softCard,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Checking your secure session...',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: palette.surfacePrimary.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        border: Border.all(color: palette.borderPrimary),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.textDanger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.textDanger,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Unable to open ThinkNote',
            style: AppTypography.headlinePrimary.copyWith(fontSize: 26),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry launch'),
            ),
          ),
        ],
      ),
    );
  }
}
