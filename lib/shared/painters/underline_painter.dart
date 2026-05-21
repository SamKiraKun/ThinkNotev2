import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class UnderlinePainter extends CustomPainter {
  const UnderlinePainter({
    this.color = AppColors.decorativeUnderline,
    this.strokeWidth = 4,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final baseline = size.height * 0.64;
    path.moveTo(0, baseline);
    path.quadraticBezierTo(size.width * 0.22, size.height, size.width * 0.46, baseline + 1.5);
    path.quadraticBezierTo(size.width * 0.68, baseline - 2.5, size.width, baseline + 1);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
