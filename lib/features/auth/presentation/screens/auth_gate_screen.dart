import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/auth_controller.dart';

class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _signInEmailController;
  late final TextEditingController _signInPasswordController;
  late final TextEditingController _signUpNameController;
  late final TextEditingController _signUpEmailController;
  late final TextEditingController _signUpPasswordController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _signInEmailController = TextEditingController();
    _signInPasswordController = TextEditingController();
    _signUpNameController = TextEditingController();
    _signUpEmailController = TextEditingController();
    _signUpPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Authentication failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: AppGradients.createAccountPanel,
                    borderRadius: BorderRadius.circular(AppRadius.formCard),
                    boxShadow: AppShadows.floatingCard,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: AppGradients.authPrimaryButton,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppShadows.floatingCard,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.cloud_done_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('ThinkNote', style: AppTypography.headlinePrimary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Move between devices without losing the speed of a local-first notes app.',
                        style: AppTypography.bodyLarge.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _FeatureRow(
                        icon: Icons.sync_rounded,
                        title: 'Cloud sync when you want it',
                        subtitle:
                            'Local changes save first, then the workspace catches up in the background.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _FeatureRow(
                        icon: Icons.mark_email_read_outlined,
                        title: 'Recovery-ready access',
                        subtitle:
                            'Password reset and verification emails are available from this sign-in flow.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Container(
                  decoration: BoxDecoration(
                    color: palette.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.formCard),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: AppColors.brandPrimary,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Sign in'),
                            Tab(text: 'Create account'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 430,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _AuthForm(
                              isBusy: isBusy,
                              emailController: _signInEmailController,
                              passwordController: _signInPasswordController,
                              onSubmit: _submitSignIn,
                              primaryLabel: 'Sign in',
                              secondaryActionLabel: 'Forgot password?',
                              onSecondaryAction: _showResetPasswordDialog,
                              footer:
                                  'Use your account to unlock synced notes and cross-device continuity.',
                            ),
                            _AuthForm(
                              isBusy: isBusy,
                              nameController: _signUpNameController,
                              emailController: _signUpEmailController,
                              passwordController: _signUpPasswordController,
                              onSubmit: _submitSignUp,
                              primaryLabel: 'Create account',
                              footer:
                                  'A verification email is sent after sign-up so recovery and account trust are easier to manage.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Email/password sign-in, password reset, and verification emails are enabled in this release. Account deletion remains available from Profile after sign-in.',
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSignIn() async {
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signInWithEmail(
          email: _signInEmailController.text,
          password: _signInPasswordController.text,
        );
  }

  Future<void> _submitSignUp() async {
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signUpWithEmail(
          email: _signUpEmailController.text,
          password: _signUpPasswordController.text,
          displayName: _signUpNameController.text,
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Account created. Check your inbox for a verification email.',
        ),
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _ResetPasswordDialog(
          initialEmail: _signInEmailController.text,
        );
      },
    );

    if (email == null || email.trim().isEmpty) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(email: email);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset email sent to ${email.trim()}.')),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
    required this.primaryLabel,
    required this.isBusy,
    required this.footer,
    this.nameController,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final TextEditingController? nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final Future<void> Function() onSubmit;
  final String primaryLabel;
  final bool isBusy;
  final String footer;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nameController != null) ...[
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'How your workspace should be labeled',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'name@example.com',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: passwordController,
            obscureText: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'At least 6 characters',
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isBusy ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(isBusy ? 'Working...' : primaryLabel),
            ),
          ),
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isBusy ? null : onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            footer,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
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
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
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

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'name@example.com',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Send reset link'),
        ),
      ],
    );
  }
}
