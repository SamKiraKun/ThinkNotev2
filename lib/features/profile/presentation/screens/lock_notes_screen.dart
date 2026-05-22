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

class LockNotesScreen extends ConsumerStatefulWidget {
  const LockNotesScreen({super.key});

  @override
  ConsumerState<LockNotesScreen> createState() => _LockNotesScreenState();
}

class _LockNotesScreenState extends ConsumerState<LockNotesScreen> {
  final _pinController = TextEditingController();
  final _verifyController = TextEditingController();
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _isEnabled =
        ref.read(sharedPreferencesProvider).getString(StorageKeys.lockPinHash) !=
            null;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _verifyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Lock notes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: palette.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.formCard),
                boxShadow: AppShadows.softCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: AppColors.brandPrimary,
                    size: 36,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _isEnabled ? 'Local lock enabled' : 'No local lock set',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'This stores a salted passcode hash on this device. Biometric enforcement and encrypted cloud note locking still require platform setup.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Set or change passcode', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'New passcode',
                helperText: 'Use at least 4 digits.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _savePin,
              child: const Text('Save passcode'),
            ),
            if (_isEnabled) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text('Verify passcode', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _verifyController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'Current passcode',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: _verifyPin,
                child: const Text('Verify'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _disableLock,
                child: Text(
                  'Disable local lock',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textDanger,
                  ),
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
      _showSnack('Use at least 4 digits.');
      return;
    }

    final preferences = ref.read(sharedPreferencesProvider);
    final salt = _createSalt();
    await preferences.setString(StorageKeys.lockPinSalt, salt);
    await preferences.setString(StorageKeys.lockPinHash, _hashPin(pin, salt));
    _pinController.clear();
    setState(() => _isEnabled = true);
    _showSnack('Local passcode saved.');
  }

  Future<void> _verifyPin() async {
    final preferences = ref.read(sharedPreferencesProvider);
    final salt = preferences.getString(StorageKeys.lockPinSalt);
    final storedHash = preferences.getString(StorageKeys.lockPinHash);
    if (salt == null || storedHash == null) {
      _showSnack('No passcode is configured.');
      return;
    }

    final isValid = _hashPin(_verifyController.text.trim(), salt) == storedHash;
    _verifyController.clear();
    _showSnack(isValid ? 'Passcode verified.' : 'Passcode did not match.');
  }

  Future<void> _disableLock() async {
    final preferences = ref.read(sharedPreferencesProvider);
    await preferences.remove(StorageKeys.lockPinSalt);
    await preferences.remove(StorageKeys.lockPinHash);
    _verifyController.clear();
    setState(() => _isEnabled = false);
    _showSnack('Local lock disabled.');
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
