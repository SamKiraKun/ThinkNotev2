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
import '../../../notes/presentation/controllers/notes_controller.dart';
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
  static const int _pageCount = 4;

  late final PageController _pageController;
  late final TextEditingController _workspaceNameController;
  int _pageIndex = 0;
  bool _didSeedValues = false;
  WorkspaceFocus _workspaceFocus = WorkspaceFocus.capture;
  bool _wantsNotifications = false;
  AppThemePreference _themePreference = AppThemePreference.system;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _workspaceNameController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _workspaceNameController.dispose();
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
            if (!_didSeedValues) {
              _didSeedValues = true;
              _workspaceNameController.text = profile.effectiveWorkspaceName ==
                      'My Workspace'
                  ? ''
                  : profile.effectiveWorkspaceName;
              _workspaceFocus = profile.workspaceFocus;
              _wantsNotifications = profile.wantsNotifications;
              _themePreference = profile.themePreference;
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      _OnboardingProgress(
                        pageIndex: _pageIndex,
                        pageCount: _pageCount,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _pageIndex = index;
                            });
                          },
                          children: [
                            _WelcomePage(syncEnabled: AppEnv.enableExperimentalSync),
                            _WorkspaceIdentityPage(
                              controller: _workspaceNameController,
                              selectedFocus: _workspaceFocus,
                              onFocusChanged: (focus) {
                                setState(() {
                                  _workspaceFocus = focus;
                                });
                              },
                            ),
                            _ExperienceSettingsPage(
                              themePreference: _themePreference,
                              wantsNotifications: _wantsNotifications,
                              onThemeChanged: (value) {
                                setState(() {
                                  _themePreference = value;
                                });
                                // Instantly preview the theme change in the UI
                                final currentPrefs = ref
                                    .read(notesControllerProvider)
                                    .valueOrNull
                                    ?.preferences;
                                if (currentPrefs != null) {
                                  ref
                                      .read(notesControllerProvider.notifier)
                                      .updatePreferences(
                                        currentPrefs.copyWith(themePreference: value),
                                      );
                                }
                              },
                              onNotificationsChanged: (value) {
                                setState(() {
                                  _wantsNotifications = value;
                                });
                              },
                            ),
                            _ReadyToLaunchPage(
                              workspaceName:
                                  _normalizedWorkspaceName(_workspaceNameController.text),
                              workspaceFocus: _workspaceFocus,
                              themePreference: _themePreference,
                              wantsNotifications: _wantsNotifications,
                              syncEnabled: AppEnv.enableExperimentalSync,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
                                      ? 'Saving...'
                                      : _pageIndex == _pageCount - 1
                                          ? (AppEnv.enableExperimentalSync
                                              ? 'Continue to Account'
                                              : 'Open Dashboard')
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

  Future<void> _advance() async {
    if (_pageIndex < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    await ref.read(onboardingControllerProvider.notifier).completeOnboarding(
          workspaceName: _normalizedWorkspaceName(_workspaceNameController.text),
          workspaceFocus: _workspaceFocus,
          wantsNotifications: _wantsNotifications,
          themePreference: _themePreference,
        );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  String _normalizedWorkspaceName(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return 'My Workspace';
    }
    return normalized;
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({
    required this.pageIndex,
    required this.pageCount,
  });

  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workspace Setup',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var index = 0; index < pageCount; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  decoration: BoxDecoration(
                    color: index <= pageIndex
                        ? AppColors.brandPrimary
                        : palette.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              if (index != pageCount - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.syncEnabled});

  final bool syncEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppGradients.createAccountPanel,
              borderRadius: BorderRadius.circular(AppRadius.formCard),
              boxShadow: AppShadows.softCard,
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppGradients.authPrimaryButton,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppShadows.floatingCard,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Welcome to a modern cloud notes platform',
                  style: AppTypography.headlinePrimary.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  syncEnabled
                      ? 'Experience a hybrid notes engine: write instantly with local caching, and let cloud sync keep all your notes backed up and synced automatically.'
                      : 'Keep your notes fast, private, organized, and available fully offline with a modern workspace custom-tailored to you.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SetupBenefit(
            icon: Icons.bolt_rounded,
            title: 'Optimistic local caching',
            subtitle: 'Write notes instantly. The app persists changes locally first, ensuring zero lag.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _SetupBenefit(
            icon: Icons.sync_rounded,
            title: syncEnabled ? 'Automatic background sync' : 'Robust offline security',
            subtitle: syncEnabled
                ? 'Your note modifications, folders, and tags catch up with the server in the background.'
                : 'All documents are encrypted at rest using local ciphers and stay exclusively on your device.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SetupBenefit(
            icon: Icons.space_dashboard_rounded,
            title: 'Workspaces and dashboard',
            subtitle: 'A clean command center organizing recent work, quick searches, and templates.',
          ),
        ],
      ),
    );
  }
}

class _WorkspaceIdentityPage extends StatelessWidget {
  const _WorkspaceIdentityPage({
    required this.controller,
    required this.selectedFocus,
    required this.onFocusChanged,
  });

  final TextEditingController controller;
  final WorkspaceFocus selectedFocus;
  final ValueChanged<WorkspaceFocus> onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'Name your workspace',
            style: AppTypography.headlinePrimary.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This title represents your command center in the dashboard and profile settings.',
            style: AppTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.borderPrimary),
              boxShadow: AppShadows.softCard,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Workspace Name',
                labelStyle: TextStyle(color: AppColors.brandPrimary.withValues(alpha: 0.8)),
                hintText: 'Product Studio, Personal Space, daily log...',
                border: InputBorder.none,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Select your primary target workflow',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final focus in WorkspaceFocus.values) ...[
            _FocusCard(
              focus: focus,
              isSelected: selectedFocus == focus,
              onTap: () => onFocusChanged(focus),
            ),
            if (focus != WorkspaceFocus.values.last)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ExperienceSettingsPage extends StatelessWidget {
  const _ExperienceSettingsPage({
    required this.themePreference,
    required this.wantsNotifications,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
  });

  final AppThemePreference themePreference;
  final bool wantsNotifications;
  final ValueChanged<AppThemePreference> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'Personalize your setup',
            style: AppTypography.headlinePrimary.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose a look and feel for this device. These settings can be updated anytime in Profile.',
            style: AppTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Theme Preference',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final preference in AppThemePreference.values) ...[
                Expanded(
                  child: _ThemeCard(
                    preference: preference,
                    isSelected: themePreference == preference,
                    onTap: () => onThemeChanged(preference),
                  ),
                ),
                if (preference != AppThemePreference.values.last)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: BorderRadius.circular(AppRadius.formCard),
              boxShadow: AppShadows.softCard,
              border: Border.all(
                color: wantsNotifications
                    ? AppColors.brandPrimary.withValues(alpha: 0.2)
                    : palette.borderPrimary,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminders & Nudges',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Receive timed notifications and review tasks scheduling in settings.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: wantsNotifications,
                  activeTrackColor: AppColors.brandPrimary,
                  onChanged: onNotificationsChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyToLaunchPage extends StatelessWidget {
  const _ReadyToLaunchPage({
    required this.workspaceName,
    required this.workspaceFocus,
    required this.themePreference,
    required this.wantsNotifications,
    required this.syncEnabled,
  });

  final String workspaceName;
  final WorkspaceFocus workspaceFocus;
  final AppThemePreference themePreference;
  final bool wantsNotifications;
  final bool syncEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'Ready to launch',
            style: AppTypography.headlinePrimary.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            syncEnabled
                ? 'Finish setup and register your secure cloud account to start syncing across devices.'
                : 'Setup is complete. Open your dashboard below to start journaling and task planning.',
            style: AppTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppGradients.pinnedCard,
              borderRadius: BorderRadius.circular(AppRadius.formCard),
              boxShadow: AppShadows.softCard,
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rocket_launch_rounded, color: AppColors.brandPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'WORKSPACE SUMMARY',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  workspaceName,
                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  workspaceFocus.label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  workspaceFocus.dashboardMessage,
                  style: AppTypography.bodyLarge.copyWith(
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(color: AppColors.formDivider),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(label: 'Theme Preferred', value: themePreference.label),
                _SummaryRow(
                  label: 'Notifications Reminders',
                  value: wantsNotifications ? 'Enabled' : 'Disabled',
                ),
                _SummaryRow(
                  label: 'Workspace Connection',
                  value: syncEnabled ? 'Cloud Sync Sync-enabled' : 'Offline local-only',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupBenefit extends StatelessWidget {
  const _SetupBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        boxShadow: AppShadows.softCard,
        border: Border.all(
          color: palette.borderPrimary,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.brandPrimary, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
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
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.focus,
    required this.isSelected,
    required this.onTap,
  });

  final WorkspaceFocus focus;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.05)
              : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : palette.borderPrimary,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.floatingCard : AppShadows.softCard,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandPrimary.withValues(alpha: 0.12)
                    : palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                focus.icon,
                color: isSelected ? AppColors.brandPrimary : palette.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    focus.label,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.brandPrimary : context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    focus.description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandPrimary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.preference,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemePreference preference;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.formCard),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.05)
              : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : palette.borderPrimary,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.floatingCard : AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              switch (preference) {
                AppThemePreference.system => Icons.settings_brightness_rounded,
                AppThemePreference.light => Icons.light_mode_rounded,
                AppThemePreference.dark => Icons.dark_mode_rounded,
              },
              color: isSelected ? AppColors.brandPrimary : palette.textSecondary,
              size: 24,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              preference.label,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.brandPrimary : context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}