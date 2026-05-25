import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_text_field.dart';

class LockNotesScreen extends ConsumerStatefulWidget {
  const LockNotesScreen({super.key});

  @override
  ConsumerState<LockNotesScreen> createState() => _LockNotesScreenState();
}

class _LockNotesScreenState extends ConsumerState<LockNotesScreen> {
  final _pinController = TextEditingController();
  final _verifyController = TextEditingController();

  final _pinFocusNode = FocusNode();
  final _verifyFocusNode = FocusNode();

  bool _isEnabled = false;
  bool _obscurePin = true;
  bool _obscureVerify = true;

  @override
  void initState() {
    super.initState();
    _isEnabled = ref
            .read(sharedPreferencesProvider)
            .getString(StorageKeys.lockPinHash) !=
        null;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _verifyController.dispose();
    _pinFocusNode.dispose();
    _verifyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        title: const Text('Workspace Lock'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: palette.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.formCard),
                boxShadow: AppShadows.softCard,
                border: Border.all(color: palette.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: AppColors.brandPrimary,
                    size: 38,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _isEnabled ? 'Passcode Lock Active' : 'Passcode Lock Inactive',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enabling a local passcode encrypts your offline session database. The app will require verification on cold startup or background restore.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Passcode Setup Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: palette.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.formCard),
                boxShadow: AppShadows.softCard,
                border: Border.all(color: palette.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEnabled ? 'Update Passcode' : 'Create Passcode',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    placeholder: 'Enter numeric passcode (4-6 digits)',
                    semanticsLabel: 'Passcode field',
                    leadingIcon: Icons.pin_rounded,
                    keyboardType: TextInputType.number,
                    obscureText: _obscurePin,
                    onChanged: (_) {},
                    trailingIcon: _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    onTrailingTap: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _savePin,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.brandPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    child: Text(_isEnabled ? 'Change Passcode' : 'Enable Passcode'),
                  ),
                ],
              ),
            ),

            if (_isEnabled) ...[
              const SizedBox(height: AppSpacing.xxl),
              // Verify & Disable Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: palette.surfacePrimary,
                  borderRadius: BorderRadius.circular(AppRadius.formCard),
                  boxShadow: AppShadows.softCard,
                  border: Border.all(color: palette.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Disable Passcode Lock', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _verifyController,
                      focusNode: _verifyFocusNode,
                      placeholder: 'Enter current passcode to verify',
                      semanticsLabel: 'Verify passcode field',
                      leadingIcon: Icons.lock_open_rounded,
                      keyboardType: TextInputType.number,
                      obscureText: _obscureVerify,
                      onChanged: (_) {},
                      trailingIcon: _obscureVerify ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onTrailingTap: () => setState(() => _obscureVerify = !_obscureVerify),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton(
                      onPressed: _disableLock,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: AppColors.textDanger,
                        side: const BorderSide(color: AppColors.textDanger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      child: const Text('Verify & Disable Lock'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      _showSnack('Passcode must be at least 4 digits.');
      return;
    }

    final preferences = ref.read(sharedPreferencesProvider);
    final salt = _createSalt();
    await preferences.setString(StorageKeys.lockPinSalt, salt);
    await preferences.setString(StorageKeys.lockPinHash, _hashPin(pin, salt));
    _pinController.clear();
    setState(() => _isEnabled = true);
    _showSnack('Passcode configured successfully.');
  }

  Future<void> _disableLock() async {
    final verifyPin = _verifyController.text.trim();
    if (verifyPin.isEmpty) {
      _showSnack('Please enter your current passcode.');
      return;
    }

    final preferences = ref.read(sharedPreferencesProvider);
    final salt = preferences.getString(StorageKeys.lockPinSalt);
    final storedHash = preferences.getString(StorageKeys.lockPinHash);
    if (salt == null || storedHash == null) {
      _showSnack('No passcode is configured.');
      return;
    }

    final isValid = _hashPin(verifyPin, salt) == storedHash;
    if (isValid) {
      await preferences.remove(StorageKeys.lockPinSalt);
      await preferences.remove(StorageKeys.lockPinHash);
      _verifyController.clear();
      setState(() => _isEnabled = false);
      _showSnack('Passcode lock disabled.');
    } else {
      _showSnack('Incorrect passcode. Verification failed.');
    }
  }

  String _createSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
