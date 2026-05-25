import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/utils/accessibility_utils.dart';
import '../../core/extensions/context_extensions.dart';
import 'animated_tap_scale.dart';

class AppIconButton extends StatelessWidget {
	const AppIconButton({
		super.key,
		required this.icon,
		required this.semanticsLabel,
		required this.onPressed,
		this.size = 48,
		this.iconSize = 22,
		this.showBadge = false,
		this.badgeColor = AppColors.decorativeNotificationDot,
	});

	final IconData icon;
	final String semanticsLabel;
	final VoidCallback? onPressed;
	final double size;
	final double iconSize;
	final bool showBadge;
	final Color badgeColor;

	@override
	Widget build(BuildContext context) {
		final isDisabled = onPressed == null;

		return Semantics(
			button: true,
			enabled: !isDisabled,
			excludeSemantics: true,
			label: semanticsLabel,
			onTap: isDisabled ? null : onPressed,
			child: AnimatedTapScale(
				onTap: onPressed,
				disabled: isDisabled,
				builder: (context, state) {
					final palette = context.palette;
					final backgroundColor = isDisabled
							? palette.surfaceSecondary
							: state.isPressed
									? palette.surfaceAccent
									: state.isHovered
											? palette.surfaceSecondary
											: palette.surfacePrimary;
					final iconColor = isDisabled
							? AppColors.buttonDisabledText
							: state.isHovered || state.isPressed
									? AppColors.brandPrimary
									: palette.textPrimary;

					return AnimatedContainer(
						duration: AccessibilityUtils.interactiveDuration(context),
						curve: AppConstants.interactiveCurve,
						width: size,
						height: size,
						constraints: const BoxConstraints(
							minWidth: AppConstants.minimumTapTarget,
							minHeight: AppConstants.minimumTapTarget,
						),
						decoration: BoxDecoration(
							color: backgroundColor,
							borderRadius: BorderRadius.circular(AppRadius.topAction),
							border: state.isFocused
									? Border.all(color: AppColors.borderFocus, width: 2)
									: null,
							boxShadow: isDisabled ? const <BoxShadow>[] : AppShadows.softCard,
						),
						child: Stack(
							clipBehavior: Clip.none,
							alignment: Alignment.center,
							children: [
								Icon(icon, size: iconSize, color: iconColor),
								if (showBadge)
									Positioned(
										top: size * 0.18,
										right: size * 0.2,
										child: Container(
											width: 7,
											height: 7,
											decoration: BoxDecoration(
												color: badgeColor,
												shape: BoxShape.circle,
												border: Border.all(color: palette.surfacePrimary, width: 1.2),
											),
										),
									),
							],
						),
					);
				},
			),
		);
	}
}
