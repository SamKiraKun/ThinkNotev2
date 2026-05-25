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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                                child: const Text('Back'),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: isBusy ? null : _advance,
                              child: Text(
                                isBusy
                                    ? 'Saving...'
                                    : _pageIndex == _pageCount - 1
                                        ? (AppEnv.enableExperimentalSync
                                            ? 'Continue to account'
                                            : 'Open dashboard')
                                        : 'Continue',
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
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
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
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
        Text('Workspace setup', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var index = 0; index < pageCount; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 8,
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

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppGradients.createAccountPanel,
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            boxShadow: AppShadows.softCard,
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
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.cloud_done_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'ThinkNote now launches like a real workspace product.',
                style: AppTypography.headlinePrimary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                syncEnabled
                    ? 'Move between devices, keep your notes cached locally, and open into a dashboard that understands what matters right now.'
                    : 'Keep your notes fast, organized, and ready offline with a setup flow that shapes the dashboard around your work.',
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _SetupBenefit(
          icon: Icons.flash_on_rounded,
          title: 'Fast capture first',
          subtitle: 'Quick actions and recent work stay visible the moment you open the app.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _SetupBenefit(
          icon: Icons.sync_rounded,
          title: syncEnabled ? 'Cloud-aware launch' : 'Offline-aware launch',
          subtitle: syncEnabled
              ? 'The app checks onboarding, account state, and your note cache before routing you in.'
              : 'The app restores your note cache and setup choices before routing you in.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SetupBenefit(
          icon: Icons.dashboard_customize_rounded,
          title: 'Structured workspace',
          subtitle: 'Dashboard, search, workspace, and profile now each have a clear job.',
        ),
      ],
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

    return ListView(
      children: [
        Text('Name your workspace', style: AppTypography.headlinePrimary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This title appears in your dashboard and profile so the app feels like your system, not a generic notes list.',
          style: AppTypography.bodyLarge.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Workspace name',
            hintText: 'Product studio, Research lab, Daily log...',
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Primary workflow', style: AppTypography.titleMedium),
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

    return ListView(
      children: [
        Text('Tune the experience', style: AppTypography.headlinePrimary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Pick how the app should feel on this device. You can change these later from Profile.',
          style: AppTypography.bodyLarge.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Theme', style: AppTypography.titleMedium),
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
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reminders and nudges', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Keep reminders available for future task and notification features.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: wantsNotifications,
                onChanged: onNotificationsChanged,
              ),
            ],
          ),
        ),
      ],
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

    return ListView(
      children: [
        Text('Ready to launch', style: AppTypography.headlinePrimary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          syncEnabled
              ? 'Finish setup and continue into account sign-in. Your dashboard will open with the workspace profile below.'
              : 'Finish setup and continue straight into your dashboard with the workspace profile below.',
          style: AppTypography.bodyLarge.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppGradients.createAccountPanel,
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            boxShadow: AppShadows.softCard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workspaceName, style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                workspaceFocus.label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                workspaceFocus.dashboardMessage,
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SummaryRow(label: 'Theme', value: themePreference.label),
              _SummaryRow(
                label: 'Reminders',
                value: wantsNotifications ? 'Enabled' : 'Not now',
              ),
              _SummaryRow(
                label: 'Launch mode',
                value: syncEnabled ? 'Cloud-aware' : 'Device-first',
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
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
                Text(title, style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.08)
              : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : palette.borderPrimary,
          ),
          boxShadow: AppShadows.softCard,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandPrimary.withValues(alpha: 0.16)
                    : palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                focus.icon,
                color:
                    isSelected ? AppColors.brandPrimary : palette.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(focus.label, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    focus.description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandPrimary,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPrimary.withValues(alpha: 0.08)
              : palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : palette.borderPrimary,
          ),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              switch (preference) {
                AppThemePreference.system => Icons.devices_rounded,
                AppThemePreference.light => Icons.light_mode_rounded,
                AppThemePreference.dark => Icons.dark_mode_rounded,
              },
              color:
                  isSelected ? AppColors.brandPrimary : palette.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(preference.label, style: AppTypography.titleSmall),
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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          Text(value, style: AppTypography.titleSmall),
        ],
      ),
    );
  }
}