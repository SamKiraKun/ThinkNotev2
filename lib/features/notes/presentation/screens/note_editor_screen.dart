import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../controllers/note_editor_controller.dart';
import '../widgets/note_editor_toolbar.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.initialFolderId,
  });

  final String? noteId;
  final String? initialFolderId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _bodyFocusNode;
  late final NoteEditorArgs _args;

  @override
  void initState() {
    super.initState();
    _args = NoteEditorArgs(
      noteId: widget.noteId,
      initialFolderId: widget.initialFolderId,
    );
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _titleFocusNode = FocusNode();
    _bodyFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final editorState = ref.watch(noteEditorControllerProvider(_args));
    final editorController =
        ref.read(noteEditorControllerProvider(_args).notifier);
    final notesState = ref.watch(notesControllerProvider).valueOrNull;
    final folder = notesState?.folderById(editorState.folderId);

    ref.listen(noteEditorControllerProvider(_args), (previous, next) {
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    if (!_titleFocusNode.hasFocus &&
        _titleController.text != editorState.title) {
      _titleController.value = _titleController.value.copyWith(
        text: editorState.title,
        selection: TextSelection.collapsed(offset: editorState.title.length),
      );
    }

    if (!_bodyFocusNode.hasFocus &&
        _bodyController.text != editorState.content) {
      _bodyController.value = _bodyController.value.copyWith(
        text: editorState.content,
        selection: TextSelection.collapsed(offset: editorState.content.length),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _saveAndClose(editorController);
      },
      child: Scaffold(
        backgroundColor: palette.pageBackground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: editorState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await _saveAndClose(editorController);
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: palette.surfacePrimary,
                              minimumSize: const Size(48, 48),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: InkWell(
                              onTap: () => _showFolderSelector(
                                context,
                                ref,
                                notesState?.folders ?? const <FolderModel>[],
                                editorState.folderId,
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: palette.surfacePrimary,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(color: palette.borderSoft),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.folder_open_rounded,
                                      color: AppColors.brandPrimary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Flexible(
                                      child: Text(
                                        folder?.displayName ?? 'Select folder',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      color: palette.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          FilledButton(
                            onPressed: editorState.isSaving
                                ? null
                                : editorController.saveNow,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              minimumSize: const Size(82, 48),
                            ),
                            child: Text(
                              editorState.isSaving ? 'Saving' : 'Save',
                              style: AppTypography.buttonLabel,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'favorite') {
                                editorController.toggleFavorite();
                              } else if (value == 'pin') {
                                editorController.togglePinned();
                              } else if (value == 'archive') {
                                await editorController.archiveCurrentNote();
                                if (context.mounted) {
                                  context.pop();
                                }
                              } else if (value == 'unarchive') {
                                await editorController.unarchiveCurrentNote();
                              } else if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => const AppConfirmationDialog(
                                    title: 'Move note to Trash?',
                                    message:
                                        'You can restore it later from Trash.',
                                    confirmLabel: 'Move to trash',
                                    isDestructive: true,
                                  ),
                                );
                                if (confirmed == true) {
                                  await editorController.deleteCurrentNote();
                                  if (context.mounted) {
                                    context.pop();
                                  }
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(
                                  editorState.isPinned
                                      ? 'Unpin note'
                                      : 'Pin note',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'favorite',
                                child: Text(
                                  editorState.isFavorite
                                      ? 'Remove favorite'
                                      : 'Mark favorite',
                                ),
                              ),
                              if (editorState.noteId != null)
                                PopupMenuItem(
                                  value: editorState.isArchived
                                      ? 'unarchive'
                                      : 'archive',
                                  child: Text(
                                    editorState.isArchived
                                        ? 'Move to notes'
                                        : 'Archive',
                                  ),
                                ),
                              if (editorState.noteId != null)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfacePrimary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.formCard,
                              ),
                              border: Border.all(color: palette.borderPrimary),
                              boxShadow: AppShadows.softCard,
                            ),
                            child: TextField(
                              controller: _titleController,
                              focusNode: _titleFocusNode,
                              onChanged: editorController.updateTitle,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Untitled note',
                                counterText: '',
                              ),
                              maxLength: 120,
                              style: AppTypography.titleLarge,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  if (editorState.isPinned)
                                    _StatusBadge(
                                      icon: Icons.push_pin_rounded,
                                      label: 'Pinned',
                                    ),
                                  if (editorState.isFavorite)
                                    _StatusBadge(
                                      icon: Icons.star_rounded,
                                      label: 'Favorite',
                                    ),
                                  if (editorState.isArchived)
                                    _StatusBadge(
                                      icon: Icons.archive_rounded,
                                      label: 'Archived',
                                    ),
                                  if (editorState.tags.isNotEmpty)
                                    for (final tag in editorState.tags)
                                      _TagBadge(label: '#$tag'),
                                ],
                              ),
                              Text(
                                editorState.lastSavedAt == null
                                    ? 'Not saved yet'
                                    : 'Saved ${DateFormatter.formatRelative(editorState.lastSavedAt!)}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: palette.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            decoration: BoxDecoration(
                              color: palette.surfacePrimary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.formCard,
                              ),
                              boxShadow: AppShadows.softCard,
                            ),
                            child: Column(
                              children: [
                                NoteEditorToolbar(
                                  onBoldTap: () => _applyInlineWrap(
                                    editorController,
                                    prefix: '**',
                                    suffix: '**',
                                    placeholder: 'bold',
                                  ),
                                  onItalicTap: () => _applyInlineWrap(
                                    editorController,
                                    prefix: '_',
                                    suffix: '_',
                                    placeholder: 'italic',
                                  ),
                                  onUnderlineTap: () => _applyInlineWrap(
                                    editorController,
                                    prefix: '<u>',
                                    suffix: '</u>',
                                    placeholder: 'underline',
                                  ),
                                  onStrikeTap: () => _applyInlineWrap(
                                    editorController,
                                    prefix: '~~',
                                    suffix: '~~',
                                    placeholder: 'strike',
                                  ),
                                  onChecklistTap: () => _applyLinePrefix(
                                    editorController,
                                    '- [ ] ',
                                  ),
                                  onBulletTap: () => _applyLinePrefix(
                                    editorController,
                                    '- ',
                                  ),
                                  onNumberedTap: () =>
                                      _applyNumberedList(editorController),
                                  onHeadingTap: () => _applyLinePrefix(
                                    editorController,
                                    '## ',
                                  ),
                                  onQuoteTap: () => _applyLinePrefix(
                                    editorController,
                                    '> ',
                                  ),
                                  onTagTap: () => _showTagSelector(
                                    context,
                                    ref,
                                    editorState.tags,
                                  ),
                                ),
                                TextField(
                                  controller: _bodyController,
                                  focusNode: _bodyFocusNode,
                                  onChanged: editorController.updateContent,
                                  maxLines: null,
                                  minLines: 8,
                                  keyboardType: TextInputType.multiline,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    border: InputBorder.none,
                                    hintText:
                                        'Start writing. This note saves automatically.',
                                    hintStyle: AppTypography.bodyLarge.copyWith(
                                      color: palette.textPlaceholder,
                                    ),
                                  ),
                                  style: AppTypography.bodyLarge.copyWith(
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                    if (!isKeyboardVisible)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfacePrimary,
                          boxShadow: AppShadows.bottomNav,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _BottomAction(
                              icon: Icons.checklist_rounded,
                              label: 'Checklist',
                              onTap: () => _applyLinePrefix(
                                editorController,
                                '- [ ] ',
                              ),
                            ),
                            _BottomAction(
                              icon: Icons.format_list_bulleted_rounded,
                              label: 'Bullet',
                              onTap: () =>
                                  _applyLinePrefix(editorController, '- '),
                            ),
                            _BottomAction(
                              icon: Icons.format_quote_rounded,
                              label: 'Quote',
                              onTap: () =>
                                  _applyLinePrefix(editorController, '> '),
                            ),
                            _BottomAction(
                              icon: Icons.sell_outlined,
                              label: 'Tag',
                              onTap: () => _showTagSelector(
                                  context, ref, editorState.tags),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _saveAndClose(NoteEditorController controller) async {
    await controller.saveNow();

    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    router.go(RouteNames.root);
  }

  void _applyInlineWrap(
    NoteEditorController controller, {
    required String prefix,
    required String suffix,
    required String placeholder,
  }) {
    final value = _bodyController.value;
    final text = value.text;
    final selection = _normalizedSelection(value.selection, text.length);
    final hasSelection = !selection.isCollapsed;
    final selectedText = text.substring(selection.start, selection.end);
    final replacement = hasSelection
        ? '$prefix$selectedText$suffix'
        : '$prefix$placeholder$suffix';
    final updatedText =
        text.replaceRange(selection.start, selection.end, replacement);
    final updatedSelection = hasSelection
        ? TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + replacement.length,
          )
        : TextSelection(
            baseOffset: selection.start + prefix.length,
            extentOffset: selection.start + prefix.length + placeholder.length,
          );
    _setBodyText(controller, updatedText, updatedSelection);
  }

  void _applyLinePrefix(NoteEditorController controller, String prefix) {
    _applyLineTransform(controller, (lines) {
      return lines
          .map((line) => '$prefix${line.trimLeft()}')
          .toList(growable: false);
    });
  }

  void _applyNumberedList(NoteEditorController controller) {
    _applyLineTransform(controller, (lines) {
      return [
        for (var index = 0; index < lines.length; index += 1)
          '${index + 1}. ${lines[index].trimLeft()}',
      ];
    });
  }

  void _applyLineTransform(
    NoteEditorController controller,
    List<String> Function(List<String> lines) transform,
  ) {
    final value = _bodyController.value;
    final text = value.text;
    final selection = _normalizedSelection(value.selection, text.length);
    final blockStart = _lineBoundaryStart(text, selection.start);
    final blockEnd = _lineBoundaryEnd(text, selection.end);
    final originalBlock = text.substring(blockStart, blockEnd);
    final originalLines =
        originalBlock.isEmpty ? const <String>[''] : originalBlock.split('\n');
    final updatedBlock = transform(originalLines).join('\n');
    final updatedText = text.replaceRange(blockStart, blockEnd, updatedBlock);
    _setBodyText(
      controller,
      updatedText,
      TextSelection.collapsed(offset: blockStart + updatedBlock.length),
    );
  }

  void _setBodyText(
    NoteEditorController controller,
    String text,
    TextSelection selection,
  ) {
    _bodyController.value = TextEditingValue(
      text: text,
      selection: selection,
    );
    controller.updateContent(text);
    _bodyFocusNode.requestFocus();
  }

  TextSelection _normalizedSelection(TextSelection selection, int textLength) {
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: textLength);
    }

    final start = selection.start.clamp(0, textLength);
    final end = selection.end.clamp(0, textLength);
    return TextSelection(
      baseOffset: start,
      extentOffset: end,
    );
  }

  int _lineBoundaryStart(String text, int offset) {
    if (offset <= 0) {
      return 0;
    }

    final index = text.lastIndexOf('\n', offset - 1);
    return index == -1 ? 0 : index + 1;
  }

  int _lineBoundaryEnd(String text, int offset) {
    final index = text.indexOf('\n', offset);
    return index == -1 ? text.length : index;
  }

  Future<void> _showFolderSelector(
    BuildContext context,
    WidgetRef ref,
    List<FolderModel> folders,
    String? selectedFolderId,
  ) async {
    final editorController =
        ref.read(noteEditorControllerProvider(_args).notifier);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select folder', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                for (final folder in folders)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(folder.displayName),
                    trailing: selectedFolderId == folder.id
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.brandPrimary)
                        : null,
                    onTap: () => Navigator.of(context).pop(folder.id),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      editorController.setFolder(selected);
    }
  }

  Future<void> _showTagSelector(
    BuildContext context,
    WidgetRef ref,
    List<String> currentTags,
  ) async {
    final notesState = ref.read(notesControllerProvider).valueOrNull;
    final editorController =
        ref.read(noteEditorControllerProvider(_args).notifier);
    final availableTags = notesState?.tags ?? const [];
    final selectedTags = currentTags.toSet();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tags'),
              content: SizedBox(
                width: 360,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tag in availableTags)
                      FilterChip(
                        label: Text(tag.displayLabel),
                        selected: selectedTags.contains(tag.label),
                        onSelected: (isSelected) {
                          setState(() {
                            if (isSelected) {
                              selectedTags.add(tag.label);
                            } else {
                              selectedTags.remove(tag.label);
                            }
                          });
                        },
                      ),
                    ActionChip(
                      label: const Text('New tag'),
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () async {
                        final label = await _showCreateInlineTagDialog(context);
                        if (label != null && label.trim().isNotEmpty) {
                          await ref
                              .read(notesControllerProvider.notifier)
                              .createTag(label.trim());
                          setState(() {
                            selectedTags.add(label.trim());
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pop(selectedTags.toList(growable: false)),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      editorController.replaceTags(result);
    }
  }

  Future<String?> _showCreateInlineTagDialog(BuildContext context) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Tag label'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created == true) {
      return controller.text.trim();
    }
    return null;
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandPrimary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceAccent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandPrimary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.borderPrimary),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: palette.textSecondary,
        ),
      ),
    );
  }
}
