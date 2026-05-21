import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/accessibility_utils.dart';
import 'animated_tap_scale.dart';

enum SocialProvider { google, apple, microsoft }

class AppSocialButton extends StatelessWidget {
  const AppSocialButton({
    super.key,
    required this.provider,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
    this.isLoading = false,
    this.height = 66,
    this.labelFontSize = 14,
  });

  final SocialProvider provider;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final verticalPadding = height <= 58 ? 6.0 : 8.0;
    final contentGap = height <= 58 ? 4.0 : 6.0;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      excludeSemantics: true,
      label: semanticsLabel,
      onTap: isDisabled ? null : onPressed,
      child: AnimatedTapScale(
        onTap: isDisabled ? null : onPressed,
        disabled: isDisabled,
        builder: (context, state) {
          final duration = AccessibilityUtils.interactiveDuration(context);
          final backgroundColor = isDisabled
              ? AppColors.surfaceMuted
              : state.isPressed
                  ? AppColors.surfaceLavender
                  : state.isHovered
                      ? AppColors.surfaceSoft
                      : AppColors.socialButtonBackground;

          return AnimatedContainer(
            duration: duration,
            curve: AppConstants.interactiveCurve,
            height: height,
            constraints: const BoxConstraints(minHeight: AppConstants.minimumTapTarget),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.socialButton),
              border: Border.all(
                color: state.isFocused
                    ? AppColors.borderFocus
                    : isDisabled
                        ? AppColors.borderDisabled
                        : AppColors.socialButtonBorder,
                width: state.isFocused ? 2 : 1,
              ),
              boxShadow: isDisabled ? const <BoxShadow>[] : AppShadows.socialButton,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: verticalPadding),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandPrimary,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SocialProviderIcon(provider: provider),
                            SizedBox(height: contentGap),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: AppTypography.socialButtonLabel.copyWith(
                                fontSize: labelFontSize,
                                color: isDisabled
                                    ? AppColors.buttonDisabledText
                                    : AppColors.socialButtonText,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SocialProviderIcon extends StatelessWidget {
  const _SocialProviderIcon({required this.provider});

  final SocialProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider) {
      case SocialProvider.google:
        return const CustomPaint(
          size: Size.square(24),
          painter: _GoogleLogoPainter(),
        );
      case SocialProvider.apple:
        return const Icon(
          Icons.apple_rounded,
          size: 25,
          color: AppColors.appleBlack,
        );
      case SocialProvider.microsoft:
        return const SizedBox(
          width: 24,
          height: 24,
          child: _MicrosoftLogo(),
        );
    }
  }
}

class _MicrosoftLogo extends StatelessWidget {
  const _MicrosoftLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Expanded(
          child: Row(
            children: [
              Expanded(child: ColoredBox(color: AppColors.microsoftRed)),
              SizedBox(width: 2),
              Expanded(child: ColoredBox(color: AppColors.microsoftGreen)),
            ],
          ),
        ),
        SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: ColoredBox(color: AppColors.microsoftBlue)),
              SizedBox(width: 2),
              Expanded(child: ColoredBox(color: AppColors.microsoftYellow)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final stroke = size.width * 0.18;

    void drawArc(Color color, double startAngle, double sweepAngle) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect.deflate(stroke / 2), startAngle, sweepAngle, false, paint);
    }

    drawArc(AppColors.googleBlue, -0.25, 1.05);
    drawArc(AppColors.googleRed, 0.82, 1.05);
    drawArc(AppColors.googleYellow, 1.95, 0.88);
    drawArc(AppColors.googleGreen, 2.78, 1.08);

    final barPaint = Paint()
      ..color = AppColors.googleBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.56, size.height * 0.5),
      Offset(size.width * 0.88, size.height * 0.5),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
