import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

class MountainIllustrationPainter extends CustomPainter {
  const MountainIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = AppColors.shadowIllustrationGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.34, size.height * 0.46, size.width * 0.58, size.height * 0.38),
      glowPaint,
    );

    final mountainRect = Rect.fromLTWH(0, size.height * 0.26, size.width, size.height * 0.74);
    final mountainPaint = Paint()
      ..shader = AppGradients.bottomMountain.createShader(mountainRect);

    final backMountain = Path()
      ..moveTo(size.width * 0.3, size.height)
      ..lineTo(size.width * 0.54, size.height * 0.46)
      ..lineTo(size.width * 0.76, size.height)
      ..close();
    canvas.drawPath(backMountain, mountainPaint);

    final frontMountain = Path()
      ..moveTo(size.width * 0.46, size.height)
      ..lineTo(size.width * 0.72, size.height * 0.18)
      ..lineTo(size.width * 0.94, size.height)
      ..close();
    canvas.drawPath(frontMountain, mountainPaint);

    final snowPaint = Paint()..color = AppColors.glassWhite;
    final snowCap = Path()
      ..moveTo(size.width * 0.68, size.height * 0.28)
      ..lineTo(size.width * 0.72, size.height * 0.18)
      ..lineTo(size.width * 0.76, size.height * 0.32)
      ..close();
    canvas.drawPath(snowCap, snowPaint);

    final flagPolePaint = Paint()
      ..color = AppColors.decorativeFlagPurple
      ..strokeWidth = size.width * 0.01;
    canvas.drawLine(
      Offset(size.width * 0.77, size.height * 0.14),
      Offset(size.width * 0.77, size.height * 0.48),
      flagPolePaint,
    );

    final flagPath = Path()
      ..moveTo(size.width * 0.77, size.height * 0.14)
      ..quadraticBezierTo(size.width * 0.88, size.height * 0.18, size.width * 0.83, size.height * 0.28)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.25, size.width * 0.77, size.height * 0.3)
      ..close();
    canvas.drawPath(
      flagPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.brandPrimaryLight, AppColors.decorativeFlagPurple],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(
          Rect.fromLTWH(size.width * 0.77, size.height * 0.14, size.width * 0.11, size.height * 0.16),
        ),
    );

    _drawCloud(canvas, size, Offset(size.width * 0.02, size.height * 0.72), size.width * 0.18);
    _drawCloud(canvas, size, Offset(size.width * 0.26, size.height * 0.8), size.width * 0.14);
    _drawCloud(canvas, size, Offset(size.width * 0.74, size.height * 0.74), size.width * 0.2);
  }

  void _drawCloud(Canvas canvas, Size size, Offset offset, double width) {
    final rect = Rect.fromLTWH(offset.dx, offset.dy, width, width * 0.42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width * 0.24)),
      Paint()..color = AppColors.decorativeCloud,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}