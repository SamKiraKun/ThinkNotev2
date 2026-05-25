import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

final appUnlockedProvider = StateProvider<bool>((ref) {
  // Starts unlocked unless a PIN is found in SharedPreferences
  final sharedPreferences = ref.read(sharedPreferencesProvider);
  final hasPin = sharedPreferences.getString(StorageKeys.lockPinHash) != null;
  return !hasPin;
});

class AppPasscodeUnlockScreen extends ConsumerStatefulWidget {
  const AppPasscodeUnlockScreen({super.key});

  @override
  ConsumerState<AppPasscodeUnlockScreen> createState() => _AppPasscodeUnlockScreenState();
}

class _AppPasscodeUnlockScreenState extends ConsumerState<AppPasscodeUnlockScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _currentDigits = [];
  String? _errorMessage;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 15.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _digitPressed(int digit) {
    if (_currentDigits.length >= 6) return;

    setState(() {
      _currentDigits.add(digit);
      _errorMessage = null;
    });

    if (_currentDigits.length == 4 || _currentDigits.length == 6) {
      // Auto-validate at 4 or 6 digits
      _verifyPasscode();
    }
  }

  void _backspacePressed() {
    if (_currentDigits.isEmpty) return;
    setState(() {
      _currentDigits.removeLast();
      _errorMessage = null;
    });
  }

  void _clearPressed() {
    setState(() {
      _currentDigits.clear();
      _errorMessage = null;
    });
  }

  Future<void> _verifyPasscode() async {
    final enteredPin = _currentDigits.join();
    final preferences = ref.read(sharedPreferencesProvider);
    final salt = preferences.getString(StorageKeys.lockPinSalt);
    final storedHash = preferences.getString(StorageKeys.lockPinHash);

    if (salt == null || storedHash == null) {
      // Safety recovery
      ref.read(appUnlockedProvider.notifier).state = true;
      return;
    }

    final enteredHash = sha256.convert(utf8.encode('$salt:$enteredPin')).toString();

    if (enteredHash == storedHash) {
      // Unlock app
      ref.read(appUnlockedProvider.notifier).state = true;
    } else {
      // Shake animation and reset
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'Incorrect passcode';
        _currentDigits.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Lock Icon header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppGradients.authAppIcon,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Workspace Locked',
                    style: AppTypography.headlinePrimary.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Enter your local passcode to decrypt notes.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Digits indicator row
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * (1.0 - _shakeController.value), 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _currentDigits.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? AppColors.brandPrimary : Colors.transparent,
                            border: Border.all(
                              color: isFilled ? AppColors.brandPrimary : palette.textPlaceholder,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textDanger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const Spacer(),

                  // Numeric Keypad Grid
                  _KeypadGrid(
                    onDigitPressed: _digitPressed,
                    onBackspace: _backspacePressed,
                    onClear: _clearPressed,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<int> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Table(
      children: [
        TableRow(
          children: [
            _KeypadButton(digit: 1, onTap: () => onDigitPressed(1)),
            _KeypadButton(digit: 2, onTap: () => onDigitPressed(2)),
            _KeypadButton(digit: 3, onTap: () => onDigitPressed(3)),
          ],
        ),
        TableRow(
          children: [
            _KeypadButton(digit: 4, onTap: () => onDigitPressed(4)),
            _KeypadButton(digit: 5, onTap: () => onDigitPressed(5)),
            _KeypadButton(digit: 6, onTap: () => onDigitPressed(6)),
          ],
        ),
        TableRow(
          children: [
            _KeypadButton(digit: 7, onTap: () => onDigitPressed(7)),
            _KeypadButton(digit: 8, onTap: () => onDigitPressed(8)),
            _KeypadButton(digit: 9, onTap: () => onDigitPressed(9)),
          ],
        ),
        TableRow(
          children: [
            _UtilityKeypadButton(
              icon: Icons.clear_rounded,
              onTap: onClear,
            ),
            _KeypadButton(digit: 0, onTap: () => onDigitPressed(0)),
            _UtilityKeypadButton(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.digit,
    required this.onTap,
  });

  final int digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: palette.surfacePrimary,
            shape: BoxShape.circle,
            border: Border.all(color: palette.borderSoft),
          ),
          alignment: Alignment.center,
          child: Text(
            '$digit',
            style: AppTypography.headline.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _UtilityKeypadButton extends StatelessWidget {
  const _UtilityKeypadButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 72,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 24,
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
