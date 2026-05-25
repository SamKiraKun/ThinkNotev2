import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
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

  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

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
        _showErrorDialog(message);
      }
    });

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App branding header
                  Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: AppGradients.authAppIcon,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppShadows.floatingCard,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'ThinkNote Workspace',
                        style: AppTypography.headlinePrimary.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Fast caching local notes with automated cloud sync.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Tabs & Forms Card
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.formCard),
                      border: Border.all(color: palette.borderPrimary),
                      boxShadow: AppShadows.softCard,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: AppColors.brandPrimary,
                          unselectedLabelColor: palette.textSecondary,
                          dividerColor: Colors.transparent,
                          indicatorColor: AppColors.brandPrimary,
                          labelStyle: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Create Account'),
                          ],
                        ),
                        const Divider(height: 1, color: AppColors.formDivider),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: _tabController.index == 0 ? 370 : 450,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Sign In Form
                              Form(
                                key: _signInFormKey,
                                child: _AuthForm(
                                  isBusy: isBusy,
                                  emailController: _signInEmailController,
                                  passwordController: _signInPasswordController,
                                  onSubmit: _submitSignIn,
                                  primaryLabel: 'Sign In',
                                  secondaryActionLabel: 'Forgot Password?',
                                  onSecondaryAction: _showResetPasswordDialog,
                                  footer: 'Verify details to access your secure note vaults.',
                                ),
                              ),
                              // Sign Up Form
                              Form(
                                key: _signUpFormKey,
                                child: _AuthForm(
                                  isBusy: isBusy,
                                  nameController: _signUpNameController,
                                  emailController: _signUpEmailController,
                                  passwordController: _signUpPasswordController,
                                  onSubmit: _submitSignUp,
                                  primaryLabel: 'Register Workspace',
                                  footer: 'A verification link will be emailed to secure your access.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Guest Mode/Deferred Auth CTA
                  OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () async {
                            final sharedPrefs = ref.read(sharedPreferencesProvider);
                            await sharedPrefs.setBool('is_guest_mode', true);
                            ref.invalidate(appStartupSnapshotProvider);
                          },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Start writing now (Guest Mode)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.brandPrimary,
                      side: const BorderSide(color: AppColors.brandPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Trust Badges Center
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: palette.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.borderSoft),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.security_rounded,
                              size: 18,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SECURITY & PRIVACY GUARANTEE',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Local data is encrypted with AES-256 ciphers at rest. Communication with our servers is secured over TLS HTTPS protocols.',
                          style: AppTypography.bodySmall.copyWith(
                            color: palette.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSignIn() async {
    if (_signInFormKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      await ref.read(authControllerProvider.notifier).signInWithEmail(
            email: _signInEmailController.text.trim(),
            password: _signInPasswordController.text,
          );
    }
  }

  Future<void> _submitSignUp() async {
    if (_signUpFormKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      await ref.read(authControllerProvider.notifier).signUpWithEmail(
            email: _signUpEmailController.text.trim(),
            password: _signUpPasswordController.text,
            displayName: _signUpNameController.text.trim(),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account registration successful! Check your inbox for a verification email.',
          ),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final palette = context.palette;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.textDanger),
              const SizedBox(width: 8),
              Text('Auth Error', style: AppTypography.titleMedium.copyWith(color: AppColors.textDanger)),
            ],
          ),
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
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
      SnackBar(content: Text('Password reset instructions sent to ${email.trim()}.')),
    );
  }
}

class _AuthForm extends StatefulWidget {
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
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.nameController != null) ...[
            TextFormField(
              controller: widget.nameController,
              textCapitalization: TextCapitalization.words,
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g., Alex Carter',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextFormField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'name@example.com',
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!regex.hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            autocorrect: false,
            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'At least 6 characters',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: palette.textTertiary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            decoration: BoxDecoration(
              gradient: widget.isBusy ? null : AppGradients.authPrimaryButton,
              borderRadius: BorderRadius.circular(AppRadius.button),
              boxShadow: widget.isBusy ? null : AppShadows.floatingCard,
            ),
            child: FilledButton(
              onPressed: widget.isBusy ? null : widget.onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text(
                widget.isBusy ? 'Authenticating...' : widget.primaryLabel,
                style: AppTypography.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (widget.secondaryActionLabel != null && widget.onSecondaryAction != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.isBusy ? null : widget.onSecondaryAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                ),
                child: Text(
                  widget.secondaryActionLabel!,
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.footer,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
  final _formKey = GlobalKey<FormState>();

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
    final palette = context.palette;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_reset_rounded, color: AppColors.brandPrimary),
          const SizedBox(width: 8),
          Text('Reset Password', style: AppTypography.titleMedium),
        ],
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'name@example.com',
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
            if (!regex.hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandPrimary),
          child: const Text('Send Reset Link'),
        ),
      ],
    );
  }
}
