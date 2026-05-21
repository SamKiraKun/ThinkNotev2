import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/accessibility_utils.dart';

class PremiumCard extends StatelessWidget {
	const PremiumCard({
		super.key,
		required this.child,
		required this.backgroundColor,
		required this.borderRadius,
		required this.borderColor,
		this.borderWidth = 1,
		this.boxShadow = const <BoxShadow>[],
		this.padding,
		this.gradient,
		this.minHeight,
	});

	final Widget child;
	final Color backgroundColor;
	final double borderRadius;
	final Color borderColor;
	final double borderWidth;
	final List<BoxShadow> boxShadow;
	final EdgeInsetsGeometry? padding;
	final Gradient? gradient;
	final double? minHeight;

	@override
	Widget build(BuildContext context) {
		final duration = AccessibilityUtils.interactiveDuration(context);

		return AnimatedContainer(
			duration: duration,
			curve: AppConstants.interactiveCurve,
			constraints: minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
			padding: padding,
			decoration: BoxDecoration(
				color: gradient == null ? backgroundColor : null,
				gradient: gradient,
				borderRadius: BorderRadius.circular(borderRadius),
				border: Border.all(color: borderColor, width: borderWidth),
				boxShadow: boxShadow,
			),
			child: child,
		);
	}
}
