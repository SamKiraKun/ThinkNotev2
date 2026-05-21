import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

enum PageIndicatorVariant { dots, pillActive, hidden }

class PageIndicator extends StatelessWidget {
  final int itemCount;
  final int activeIndex;
  final PageIndicatorVariant variant;
  
  const PageIndicator({
    super.key,
    required this.itemCount,
    required this.activeIndex,
    this.variant = PageIndicatorVariant.dots,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == PageIndicatorVariant.hidden) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Onboarding page ${activeIndex + 1} of $itemCount',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(itemCount, (index) {
            final isActive = index == activeIndex;
            final isPill = variant == PageIndicatorVariant.pillActive && isActive;

            return AnimatedContainer(
              key: ValueKey<String>('page-indicator-dot-$index'),
              duration: AppConstants.interactiveDuration,
              curve: AppConstants.interactiveCurve,
              margin: EdgeInsets.only(right: index == itemCount - 1 ? 0 : 8),
              width: isPill ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isActive ? AppColors.indicatorActive : AppColors.indicatorInactive,
              ),
            );
          }),
        ),
      ),
    );
  }
}
