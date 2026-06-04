import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/auth_providers.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../data/models/onboarding_profile.dart';
import '../controllers/onboarding_controller.dart';

class OnboardingExperienceScreen extends ConsumerStatefulWidget {
  const OnboardingExperienceScreen({super.key});

  @override
  ConsumerState<OnboardingExperienceScreen> createState() =>
      _OnboardingExperienceScreenState();
}

class _OnboardingExperienceScreenState
    extends ConsumerState<OnboardingExperienceScreen> {
  static const int _pageCount = 3;
  static const List<_OnboardingPageContent> _slides = [
    _OnboardingPageContent(
      eyebrow: 'Start fast',
      headline: 'Write anything instantly.',
      description:
          'Capture ideas, tasks, and journal thoughts without setup friction. Your first note is always one tap away.',
    ),
    _OnboardingPageContent(
      eyebrow: 'Stay organized',
      headline: 'Designed for your ideas.',
      description:
          'Keep notes easy to find with folders, tags, and quick search once you sign in to your secure account.',
    ),
    _OnboardingPageContent(
      eyebrow: 'Built for trust',
      headline: 'Private and secure.',
      description:
          'ThinkNote protects access with Firebase Authentication and keeps your notes tied to your signed-in account.',
    ),
  ];

  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onboardingState = ref.watch(onboardingControllerProvider);
    final isBusy = onboardingState.isLoading;
    final currentSlide = _slides[_pageIndex];

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _OnboardingBackdrop()),
            onboardingState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.textDanger,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Unable to load setup',
                        style: AppTypography.headlinePrimary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        error.toString().replaceFirst('Exception: ', ''),
                        style: AppTypography.bodyLarge.copyWith(
                          color: palette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/icons/logo.png',
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'ThinkNote',
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            if (_pageIndex < _pageCount - 1)
                              TextButton(
                                onPressed: isBusy ? null : _skipToFinal,
                                child: Text(
                                  'Skip',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _pageCount,
                            onPageChanged: (index) {
                              setState(() {
                                _pageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final slide = _slides[index];
                              return _OnboardingSlide(
                                eyebrow: slide.eyebrow,
                                headline: slide.headline,
                                description: slide.description,
                                visual: switch (index) {
                                  0 => _buildComposerPreview(context),
                                  1 => _buildFeaturePreview(context),
                                  _ => _buildTrustPreview(context),
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pageCount, (index) {
                            final isActive = _pageIndex == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              height: 6,
                              width: isActive ? 24 : 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.brandPrimary
                                    : palette.textPlaceholder.withValues(
                                        alpha: 0.45,
                                      ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color:
                                palette.surfacePrimary.withValues(alpha: 0.88),
                            borderRadius:
                                BorderRadius.circular(AppRadius.formCard),
                            border: Border.all(color: palette.borderSoft),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _helperTextFor(currentSlide),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: palette.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            if (_pageIndex > 0) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isBusy ? null : _goBack,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(54),
                                    side: BorderSide(
                                        color: palette.borderPrimary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.button,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Back',
                                    style: AppTypography.titleSmall.copyWith(
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            Expanded(
                              flex: _pageIndex > 0 ? 2 : 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: isBusy
                                      ? null
                                      : AppGradients.authPrimaryButton,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  boxShadow:
                                      isBusy ? null : AppShadows.floatingCard,
                                ),
                                child: FilledButton(
                                  onPressed: isBusy ? null : _advance,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    minimumSize: const Size.fromHeight(54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.button,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    isBusy
                                        ? 'Preparing...'
                                        : _pageIndex == _pageCount - 1
                                            ? 'Get Started'
                                            : 'Continue',
                                    style: AppTypography.titleSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _helperTextFor(_OnboardingPageContent slide) {
    return switch (slide.headline) {
      'Private and secure.' =>
        'You will sign in after onboarding before you can open notes, folders, or profile data.',
      _ => 'Finish onboarding, then continue to secure sign-in.',
    };
  }

  Widget _buildComposerPreview(BuildContext context) {
    final palette = context.palette;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppGradients.createAccountPanel,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: palette.borderPrimary),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: palette.surfacePrimary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Quick capture',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.bolt_rounded,
                color: AppColors.brandPrimary.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Idea drop',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Draft fast, then shape it later.',
            style: AppTypography.headline.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.md),
          _PreviewLine(widthFactor: 1, color: palette.borderSoft),
          const SizedBox(height: AppSpacing.sm),
          _PreviewLine(widthFactor: 0.82, color: palette.borderSoft),
          const SizedBox(height: AppSpacing.sm),
          _PreviewLine(widthFactor: 0.9, color: palette.borderSoft),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MiniTag(
                label: 'Pinned',
                backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.12),
                textColor: AppColors.brandPrimary,
              ),
              _MiniTag(
                label: 'Secure sync',
                backgroundColor: palette.surfacePrimary.withValues(alpha: 0.82),
                textColor: palette.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePreview(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFeatureItem(
          context,
          icon: Icons.sync_rounded,
          title: 'Authenticated sync',
          subtitle:
              'Sign in once, then keep notes, folders, and tags attached to your account.',
        ),
        const SizedBox(height: AppSpacing.md),
        _buildFeatureItem(
          context,
          icon: Icons.folder_open_rounded,
          title: 'Folders and tags',
          subtitle: 'Organize work, study, and personal notes without clutter.',
        ),
        const SizedBox(height: AppSpacing.md),
        _buildFeatureItem(
          context,
          icon: Icons.search_rounded,
          title: 'Instant search',
          subtitle:
              'Find what matters quickly with lightweight, readable structure.',
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final palette = context.palette;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfacePrimary.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.borderSoft),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.brandPrimary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPreview(BuildContext context) {
    final palette = context.palette;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surfacePrimary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: palette.borderSoft),
        boxShadow: AppShadows.floatingCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppGradients.createAccountPanel,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.brandPrimary,
              size: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Calm by default',
            style: AppTypography.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _TrustRow(
            icon: Icons.smartphone_rounded,
            label: 'Sign in after setup to unlock your notes.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _TrustRow(
            icon: Icons.notifications_none_rounded,
            label: 'Permissions appear only when the feature needs them.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _TrustRow(
            icon: Icons.visibility_off_outlined,
            label: 'No ads and no noisy setup wall before writing.',
          ),
        ],
      ),
    );
  }

  Future<void> _advance() async {
    if (_pageIndex < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    await _finishOnboarding();
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _skipToFinal() async {
    await _pageController.animateToPage(
      _pageCount - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding(
          workspaceName: 'My Workspace',
          workspaceFocus: WorkspaceFocus.capture,
          wantsNotifications: false,
          themePreference: AppThemePreference.system,
        );

    if (!mounted) {
      return;
    }

    final hasSession = ref.read(currentAuthSessionProvider) != null;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(hasSession ? RouteNames.root : RouteNames.auth);
    }
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            top: -72,
            right: -28,
            child: _BackdropGlow(
              size: 220,
              colors: [
                Color(0x206F63FF),
                Color(0x10B69BFF),
                Color(0x00B69BFF),
              ],
            ),
          ),
          Positioned(
            top: 240,
            left: -52,
            child: _BackdropGlow(
              size: 180,
              colors: [
                Color(0x18F3A7D8),
                Color(0x106F63FF),
                Color(0x006F63FF),
              ],
            ),
          ),
          Positioned(
            bottom: -94,
            right: 18,
            child: _BackdropGlow(
              size: 260,
              colors: [
                Color(0x16B69BFF),
                Color(0x126F63FF),
                Color(0x006F63FF),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({
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

class _OnboardingPageContent {
  const _OnboardingPageContent({
    required this.eyebrow,
    required this.headline,
    required this.description,
  });

  final String eyebrow;
  final String headline;
  final String description;
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.visual,
  });

  final String eyebrow;
  final String headline;
  final String description;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxHeight < 460;

        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: compactLayout ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: visual,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: compactLayout ? AppSpacing.md : AppSpacing.xl,
              ),
              Text(
                eyebrow.toUpperCase(),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.brandPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(
                height: compactLayout ? AppSpacing.xs : AppSpacing.sm,
              ),
              Text(
                headline,
                style: AppTypography.headlinePrimary.copyWith(
                  fontSize: compactLayout ? 28 : 30,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                height: compactLayout ? AppSpacing.xs : AppSpacing.sm,
              ),
              Text(
                description,
                style: (compactLayout
                        ? AppTypography.bodyMedium
                        : AppTypography.bodyLarge)
                    .copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.widthFactor,
    required this.color,
  });

  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.brandPrimary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
