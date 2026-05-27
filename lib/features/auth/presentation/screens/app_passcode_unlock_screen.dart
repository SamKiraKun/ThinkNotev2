import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/security/app_passcode_store.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

final appUnlockedProvider = StateProvider<bool>((ref) {
  final hasPin = ref.read(appPasscodeStoreProvider).hasConfiguredPasscode();
  return !hasPin;
});

class AppPasscodeUnlockScreen extends ConsumerStatefulWidget {
  const AppPasscodeUnlockScreen({super.key});

  @override
  ConsumerState<AppPasscodeUnlockScreen> createState() => _AppPasscodeUnlockScreenState();
}

class _AppPasscodeUnlockScreenState extends ConsumerState<AppPasscodeUnlockScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxFailedAttemptsBeforeCooldown = 5;
  static const Duration _cooldownDuration = Duration(seconds: 30);

  final List<int> _currentDigits = [];
  String? _errorMessage;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;
  Timer? _cooldownTimer;
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
    _restoreThrottleState();
    ref.read(appPasscodeStoreProvider).migrateLegacyPasscodeIfNeeded();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  bool get _isCooldownActive =>
      _cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now());

  int get _cooldownSecondsRemaining {
    if (!_isCooldownActive) {
      return 0;
    }

    final difference = _cooldownUntil!.difference(DateTime.now());
    return difference.inSeconds <= 0 ? 1 : difference.inSeconds + 1;
  }

  void _digitPressed(int digit) {
    if (_isCooldownActive) {
      setState(() {
        _errorMessage =
            'Too many incorrect attempts. Try again in ${_cooldownSecondsRemaining}s.';
      });
      return;
    }

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
    if (_isCooldownActive) return;
    if (_currentDigits.isEmpty) return;
    setState(() {
      _currentDigits.removeLast();
      _errorMessage = null;
    });
  }

  void _clearPressed() {
    if (_isCooldownActive) return;
    setState(() {
      _currentDigits.clear();
      _errorMessage = null;
    });
  }

  Future<void> _verifyPasscode() async {
    final enteredPin = _currentDigits.join();
    final secrets = await ref.read(appPasscodeStoreProvider).readSecrets();

    if (secrets == null) {
      // Safety recovery
      await ref.read(appPasscodeStoreProvider).clearSecrets();
      ref.read(appUnlockedProvider.notifier).state = true;
      return;
    }

    final enteredHash =
        sha256.convert(utf8.encode('${secrets.salt}:$enteredPin')).toString();

    if (enteredHash == secrets.hash) {
      await _clearThrottleState();
      // Unlock app
      ref.read(appUnlockedProvider.notifier).state = true;
    } else {
      // Shake animation and reset
      _shakeController.forward(from: 0.0);
      await _recordFailedAttempt();
    }
  }

  void _restoreThrottleState() {
    final preferences = ref.read(sharedPreferencesProvider);
    _failedAttempts = preferences.getInt(StorageKeys.lockFailedAttempts) ?? 0;
    final cooldownUntilMs =
        preferences.getInt(StorageKeys.lockCooldownUntilMs);

    if (cooldownUntilMs == null) {
      return;
    }

    final cooldownUntil =
        DateTime.fromMillisecondsSinceEpoch(cooldownUntilMs);
    if (cooldownUntil.isAfter(DateTime.now())) {
      _cooldownUntil = cooldownUntil;
      _startCooldownTicker();
      return;
    }

    _clearThrottleState();
  }

  Future<void> _recordFailedAttempt() async {
    final preferences = ref.read(sharedPreferencesProvider);
    _failedAttempts += 1;

    if (_failedAttempts >= _maxFailedAttemptsBeforeCooldown) {
      _failedAttempts = 0;
      _cooldownUntil = DateTime.now().add(_cooldownDuration);
      await preferences.remove(StorageKeys.lockFailedAttempts);
      await preferences.setInt(
        StorageKeys.lockCooldownUntilMs,
        _cooldownUntil!.millisecondsSinceEpoch,
      );
      _startCooldownTicker();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentDigits.clear();
        _errorMessage =
            'Too many incorrect attempts. Try again in ${_cooldownSecondsRemaining}s.';
      });
      return;
    }

    await preferences.setInt(StorageKeys.lockFailedAttempts, _failedAttempts);

    if (!mounted) {
      return;
    }

    setState(() {
      _currentDigits.clear();
      final remainingAttempts =
          _maxFailedAttemptsBeforeCooldown - _failedAttempts;
      _errorMessage = remainingAttempts == 1
          ? 'Incorrect passcode. 1 attempt left before a short lock.'
          : 'Incorrect passcode. $remainingAttempts attempts left before a short lock.';
    });
  }

  void _startCooldownTicker() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isCooldownActive) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Too many incorrect attempts. Try again in ${_cooldownSecondsRemaining}s.';
          });
        }
        return;
      }

      timer.cancel();
      await _clearThrottleState();

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Passcode unlocked again. You can retry now.';
      });
    });
  }

  Future<void> _clearThrottleState() async {
    final preferences = ref.read(sharedPreferencesProvider);
    _cooldownTimer?.cancel();
    _cooldownUntil = null;
    _failedAttempts = 0;
    await preferences.remove(StorageKeys.lockFailedAttempts);
    await preferences.remove(StorageKeys.lockCooldownUntilMs);
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
                    'Enter your local passcode to unlock this workspace on this device.',
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
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isCooldownActive ? 0.45 : 1,
                    child: _KeypadGrid(
                      onDigitPressed: _digitPressed,
                      onBackspace: _backspacePressed,
                      onClear: _clearPressed,
                    ),
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
