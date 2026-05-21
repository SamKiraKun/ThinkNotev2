import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class DecorativeCloudPainter extends CustomPainter {
  const DecorativeCloudPainter({
    this.color = AppColors.decorativeCloud,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.12, size.height * 0.46, size.width * 0.28, size.height * 0.46)
      ..quadraticBezierTo(size.width * 0.33, size.height * 0.2, size.width * 0.48, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.08, size.width * 0.74, size.height * 0.28)
      ..quadraticBezierTo(size.width * 0.92, size.height * 0.3, size.width * 0.88, size.height * 0.68)
      ..lineTo(size.width * 0.12, size.height * 0.72)
      ..close();

    final shadowPaint = Paint()
      ..color = AppColors.shadowSoft
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DecorativeCloudPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
