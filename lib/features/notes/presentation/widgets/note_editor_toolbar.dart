import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/animated_tap_scale.dart';

class NoteEditorToolbar extends StatelessWidget {
  const NoteEditorToolbar({
    super.key,
    required this.onBoldTap,
    required this.onItalicTap,
    required this.onChecklistTap,
    required this.onBulletTap,
    required this.onNumberedTap,
    required this.onHeadingTap,
    required this.onQuoteTap,
    required this.onTagTap,
  });

  final VoidCallback onBoldTap;
  final VoidCallback onItalicTap;
  final VoidCallback onChecklistTap;
  final VoidCallback onBulletTap;
  final VoidCallback onNumberedTap;
  final VoidCallback onHeadingTap;
  final VoidCallback onQuoteTap;
  final VoidCallback onTagTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        border: Border(
          bottom: BorderSide(color: palette.borderSoft),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              onTap: onBoldTap,
            ),
            _ToolbarButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              onTap: onItalicTap,
            ),
            _ToolbarButton(
              icon: Icons.checklist_rounded,
              tooltip: 'Checklist',
              onTap: onChecklistTap,
            ),
            _ToolbarButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet list',
              onTap: onBulletTap,
            ),
            _ToolbarButton(
              icon: Icons.format_list_numbered_rounded,
              tooltip: 'Numbered list',
              onTap: onNumberedTap,
            ),
            _ToolbarButton(
              icon: Icons.title_rounded,
              tooltip: 'Heading',
              onTap: onHeadingTap,
            ),
            _ToolbarButton(
              icon: Icons.format_quote_rounded,
              tooltip: 'Quote',
              onTap: onQuoteTap,
            ),
            _ToolbarButton(
              icon: Icons.sell_outlined,
              tooltip: 'Tags',
              onTap: onTagTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: tooltip,
      child: AnimatedTapScale(
        onTap: onTap,
        tapScale: 0.9,
        builder: (context, state) {
          return Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: BoxDecoration(
              color: state.isPressed
                  ? palette.surfaceAccent
                  : state.isHovered
                      ? palette.surfaceSecondary
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: state.isPressed ? AppColors.brandPrimary : palette.textSecondary,
              size: 20,
            ),
          );
        },
      ),
    );
  }
}
