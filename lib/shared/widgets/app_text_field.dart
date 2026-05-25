import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/extensions/context_extensions.dart';

class AppTextField extends StatefulWidget {
	const AppTextField({
		super.key,
		required this.controller,
		required this.focusNode,
		required this.placeholder,
		required this.semanticsLabel,
		required this.leadingIcon,
		required this.onChanged,
		this.keyboardType = TextInputType.text,
		this.obscureText = false,
		this.enabled = true,
		this.errorText,
		this.trailingIcon,
		this.onTrailingTap,
		this.trailingSemanticsLabel,
		this.showDivider = true,
		this.rowHeight = 54,
		this.iconBoxSize = 30,
		this.iconSize = 18,
		this.textInputAction,
		this.autofillHints,
		this.onSubmitted,
	});

	final TextEditingController controller;
	final FocusNode focusNode;
	final String placeholder;
	final String semanticsLabel;
	final IconData leadingIcon;
	final ValueChanged<String> onChanged;
	final TextInputType keyboardType;
	final bool obscureText;
	final bool enabled;
	final String? errorText;
	final IconData? trailingIcon;
	final VoidCallback? onTrailingTap;
	final String? trailingSemanticsLabel;
	final bool showDivider;
	final double rowHeight;
	final double iconBoxSize;
	final double iconSize;
	final TextInputAction? textInputAction;
	final Iterable<String>? autofillHints;
	final ValueChanged<String>? onSubmitted;

	@override
	State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
	bool _isHovered = false;

	@override
	void initState() {
		super.initState();
		widget.focusNode.addListener(_handleFocusChange);
	}

	@override
	void didUpdateWidget(covariant AppTextField oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.focusNode != widget.focusNode) {
			oldWidget.focusNode.removeListener(_handleFocusChange);
			widget.focusNode.addListener(_handleFocusChange);
		}
	}

	@override
	void dispose() {
		widget.focusNode.removeListener(_handleFocusChange);
		super.dispose();
	}

	void _handleFocusChange() {
		if (mounted) {
			setState(() {});
		}
	}

	@override
	Widget build(BuildContext context) {
		final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
		final hasFocus = widget.focusNode.hasFocus;
		final isActive = widget.controller.text.isNotEmpty;
		final palette = context.palette;
		final dividerColor = hasError
				? AppColors.textDanger
				: hasFocus
						? AppColors.borderFocus
						: isActive
								? AppColors.brandPrimary
								: _isHovered
										? AppColors.buttonSecondaryBorder
										: palette.borderSoft;
		final iconColor = hasError
				? AppColors.textDanger
				: hasFocus || isActive || _isHovered
						? AppColors.brandPrimary
						: palette.textSecondary;
		final placeholderColor = widget.enabled
				? hasError
						? AppColors.textDanger
						: hasFocus || _isHovered
								? palette.textTertiary
								: palette.textPlaceholder
				: AppColors.buttonDisabledText;

		return MouseRegion(
			onEnter: (_) => setState(() => _isHovered = true),
			onExit: (_) => setState(() => _isHovered = false),
			child: Semantics(
				textField: true,
				enabled: widget.enabled,
				label: widget.semanticsLabel,
				value: widget.controller.text,
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					mainAxisSize: MainAxisSize.min,
					children: [
						SizedBox(
							height: widget.rowHeight,
							child: Row(
								children: [
									Container(
										width: widget.iconBoxSize,
										height: widget.iconBoxSize,
										decoration: BoxDecoration(
											color: widget.enabled
													? AppColors.formFieldIconBackground
													: AppColors.surfaceMuted,
											borderRadius: BorderRadius.circular(AppRadius.inputIconBox),
										),
										child: Icon(
											widget.leadingIcon,
											size: widget.iconSize,
											color: iconColor,
										),
									),
									const SizedBox(width: 12),
									Expanded(
										child: TextField(
											controller: widget.controller,
											focusNode: widget.focusNode,
											onChanged: widget.onChanged,
											enabled: widget.enabled,
											keyboardType: widget.keyboardType,
											obscureText: widget.obscureText,
											textInputAction: widget.textInputAction,
											autofillHints: widget.autofillHints,
											enableSuggestions: !widget.obscureText,
											autocorrect: !widget.obscureText &&
													widget.keyboardType != TextInputType.emailAddress,
											onSubmitted: widget.onSubmitted,
											cursorColor: AppColors.brandPrimary,
											style: AppTypography.inputText.copyWith(
												color: widget.enabled
														? palette.textPrimary
														: AppColors.buttonDisabledText,
											),
											decoration: InputDecoration(
												hintText: widget.placeholder,
												hintStyle: AppTypography.inputPlaceholder.copyWith(
													color: placeholderColor,
												),
												isDense: true,
												border: InputBorder.none,
												focusedBorder: InputBorder.none,
												enabledBorder: InputBorder.none,
												disabledBorder: InputBorder.none,
												contentPadding: EdgeInsets.zero,
											),
										),
									),
									if (widget.trailingIcon != null)
										Semantics(
											button: true,
											label: widget.trailingSemanticsLabel,
											child: IconButton(
												onPressed: widget.enabled ? widget.onTrailingTap : null,
												padding: EdgeInsets.zero,
												constraints: const BoxConstraints(
													minWidth: AppConstants.minimumTapTarget,
													minHeight: AppConstants.minimumTapTarget,
												),
												splashRadius: 22,
												icon: Icon(
													widget.trailingIcon,
													size: 22,
													color: widget.enabled ? iconColor : AppColors.buttonDisabledText,
												),
											),
										),
								],
							),
						),
						if (widget.showDivider)
							Container(
								height: 1,
								color: widget.enabled ? dividerColor : AppColors.borderDisabled,
							),
						if (hasError) ...[
							const SizedBox(height: 6),
							Semantics(
								liveRegion: true,
								child: Padding(
									padding: EdgeInsets.only(left: widget.iconBoxSize + 12),
									child: Text(
										widget.errorText!,
										style: AppTypography.bodySmall.copyWith(color: AppColors.textDanger),
									),
								),
							),
						],
					],
				),
			),
		);
	}
}
