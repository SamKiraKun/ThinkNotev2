import 'package:flutter/material.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_shadows.dart';

class GradientFab extends StatelessWidget {
  final VoidCallback onTap;
  const GradientFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.primaryCta,
          border: Border.all(color: palette.surfacePrimary, width: 6),
          boxShadow: AppShadows.fabGlow,
        ),
        child: Icon(Icons.add, color: context.colors.onPrimary, size: 28),
      ),
    );
  }
}
