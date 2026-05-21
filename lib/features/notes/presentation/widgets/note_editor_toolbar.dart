import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class NoteEditorToolbar extends StatelessWidget {
  const NoteEditorToolbar({
    super.key,
    required this.onBoldTap,
    required this.onItalicTap,
    required this.onUnderlineTap,
    required this.onStrikeTap,
    required this.onChecklistTap,
    required this.onBulletTap,
    required this.onNumberedTap,
    required this.onHeadingTap,
    required this.onQuoteTap,
    required this.onTagTap,
  });

  final VoidCallback onBoldTap;
  final VoidCallback onItalicTap;
  final VoidCallback onUnderlineTap;
  final VoidCallback onStrikeTap;
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
              icon: Icons.format_underlined_rounded,
              tooltip: 'Underline',
              onTap: onUnderlineTap,
            ),
            _ToolbarButton(
              icon: Icons.format_strikethrough_rounded,
              tooltip: 'Strikethrough',
              onTap: onStrikeTap,
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

    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: palette.textSecondary),
    );
  }
}
