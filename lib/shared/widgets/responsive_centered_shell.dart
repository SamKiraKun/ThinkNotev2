import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive_breakpoints.dart';

class ResponsiveCenteredShell extends StatelessWidget {
  final Widget child;
  final bool usePresentationFrame;
  
  const ResponsiveCenteredShell({
    super.key,
    required this.child,
    this.usePresentationFrame = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebOrTablet = constraints.maxWidth > ResponsiveBreakpoints.largePhone;
        final shell = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.contentMaxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: isWebOrTablet && usePresentationFrame
                  ? BorderRadius.circular(AppRadius.phoneFrame)
                  : BorderRadius.zero,
              boxShadow: isWebOrTablet && usePresentationFrame
                  ? AppShadows.phoneFrame
                  : const <BoxShadow>[],
            ),
            child: child,
          ),
        );

        return ColoredBox(
          color: isWebOrTablet ? palette.pageBackground : palette.surfacePrimary,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWebOrTablet ? AppSpacing.xl : 0,
                vertical: isWebOrTablet && usePresentationFrame ? AppSpacing.xl : 0,
              ),
              child: shell,
            ),
          ),
        );
      },
    );
  }
}
