import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

class NotebookIconPainter extends CustomPainter {
  const NotebookIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final coverRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.22, size.height * 0.18, size.width * 0.56, size.height * 0.64),
      Radius.circular(size.width * 0.16),
    );
    final coverPaint = Paint()
      ..shader = AppGradients.authAppIcon.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    canvas.drawRRect(coverRect, coverPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..color = AppColors.brandPrimary
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(coverRect, strokePaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..color = AppColors.brandPrimary
      ..strokeCap = StrokeCap.round;
    for (final factor in <double>[0.3, 0.45, 0.6]) {
      final path = Path()
        ..moveTo(size.width * 0.1, size.height * factor)
        ..quadraticBezierTo(
          size.width * 0.18,
          size.height * factor,
          size.width * 0.24,
          size.height * factor,
        );
      canvas.drawPath(path, ringPaint);
    }

    final linePaint = Paint()
      ..color = AppColors.brandPrimary.withValues(alpha: 0.8)
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.38),
      Offset(size.width * 0.68, size.height * 0.38),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.54),
      Offset(size.width * 0.62, size.height * 0.54),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}