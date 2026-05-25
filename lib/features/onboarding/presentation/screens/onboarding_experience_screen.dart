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

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        child: onboardingState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.brandPrimary,
            ),
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
          data: (profile) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      // Header Branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.authPrimaryButton,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'ThinkNote',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Carousel Content
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _pageIndex = index;
                            });
                          },
                          children: [
                            _OnboardingSlide(
                              headline: 'Write anything instantly.',
                              description:
                                  'Capture ideas, quick lists, and daily logs in a flash. Optimistic local caching ensures you never experience lag.',
                              visual: _buildMockNoteEditor(context),
                            ),
                            _OnboardingSlide(
                              headline: 'Designed for your ideas.',
                              description:
                                  'Keep your thoughts structured. Filter and organize notes dynamically using folders and customizable hashtags.',
                              visual: _buildMockFeaturesList(context),
                            ),
                            _OnboardingSlide(
                              headline: 'Private and secure.',
                              description:
                                  'Your notes stay yours. We protect local databases with secure device encryption, without cookies, ads, or tracking.',
                              visual: _buildMockSecurityPanel(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Pagination Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pageCount, (index) {
                          final isActive = _pageIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: isActive ? 20 : 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.brandPrimary
                                  : palette.textPlaceholder.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Buttons Row
                      Row(
                        children: [
                          if (_pageIndex > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isBusy ? null : _goBack,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: palette.borderPrimary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.button),
                                  ),
                                ),
                                child: Text(
                                  'Back',
                                  style: AppTypography.titleSmall.copyWith(
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: isBusy
                                    ? null
                                    : AppGradients.authPrimaryButton,
                                borderRadius: BorderRadius.circular(AppRadius.button),
                                boxShadow: isBusy ? null : AppShadows.floatingCard,
                              ),
                              child: FilledButton(
                                onPressed: isBusy ? null : _advance,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.button),
                                  ),
                                ),
                                child: Text(
                                  isBusy
                                      ? 'Initializing...'
                                      : _pageIndex == _pageCount - 1
                                          ? 'Get Started'
                                          : 'Continue',
                                  style: AppTypography.titleSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildMockNoteEditor(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        border: Border.all(color: palette.borderPrimary),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.borderSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 18,
            width: 140,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: palette.borderSoft,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            width: 180,
            decoration: BoxDecoration(
              color: palette.borderSoft,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockFeaturesList(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFeatureItem(context, Icons.sync_rounded, 'Sync across devices'),
        const SizedBox(height: AppSpacing.sm),
        _buildFeatureItem(context, Icons.text_fields_rounded, 'Rich text support'),
        const SizedBox(height: AppSpacing.sm),
        _buildFeatureItem(context, Icons.folder_open_rounded, 'Folders and hashtags'),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String label) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderPrimary),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brandPrimary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockSecurityPanel(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.createAccountPanel,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.1)),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.security_rounded, color: AppColors.brandPrimary, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Secure & Private',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AES-256 Local Encryption\nNo tracking · Zero ads',
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _advance() async {
    if (_pageIndex < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    await _finishOnboarding();
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _skipToFinal() async {
    await _pageController.animateToPage(
      _pageCount - 1,
      duration: const Duration(milliseconds: 300),
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
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.headline,
    required this.description,
    required this.visual,
  });

  final String headline;
  final String description;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: visual,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            headline,
            style: AppTypography.headline.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}