import 'dart:async';
import 'dart:math' as math;

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
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/presentation/widgets/folder_visuals.dart';
import '../../data/models/note_model.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../controllers/note_editor_controller.dart';
import '../widgets/note_editor_toolbar.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.initialFolderId,
    this.initialNote,
  });

  final String? noteId;
  final String? initialFolderId;
  final NoteModel? initialNote;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _bodyFocusNode;
  late final ScrollController _bodyScrollController;
  late final NoteEditorArgs _args;

  @override
  void initState() {
    super.initState();
    _args = NoteEditorArgs(
      noteId: widget.noteId,
      initialFolderId: widget.initialFolderId,
      initialNote: widget.initialNote,
    );
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _titleFocusNode = FocusNode();
    _bodyFocusNode = FocusNode();
    _bodyScrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final editorController =
          ref.read(noteEditorControllerProvider(_args).notifier);
      editorController.saveNow(queueSyncImmediately: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLoading = ref.watch(
        noteEditorControllerProvider(_args).select((state) => state.isLoading));
    final editorController =
        ref.read(noteEditorControllerProvider(_args).notifier);

    // Watcher listeners to safely sync text fields and display error snackbars.
    ref.listen<NoteEditorState>(noteEditorControllerProvider(_args),
        (previous, next) {
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }

      // Populate text controllers on initial load completion
      if (previous?.isLoading != next.isLoading && !next.isLoading) {
        _titleController.text = next.title;
        _bodyController.text = next.content;
      } else {
        // Safe synchronization when fields do not have focus
        if (!_titleFocusNode.hasFocus && _titleController.text != next.title) {
          _titleController.text = next.title;
        }
        if (!_bodyFocusNode.hasFocus && _bodyController.text != next.content) {
          _bodyController.text = next.content;
        }
      }
    });

    if (isLoading) {
      return Scaffold(
        backgroundColor: palette.pageBackground,
        body: const SafeArea(
          child: AppLoadingState(
            title: 'Opening note',
            message: 'Preparing a clean writing space.',
          ),
        ),
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
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _EditorAppBar(
                args: _args,
                onBackTap: () => _saveAndClose(editorController),
                onSaveTap: () async {
                  FocusScope.of(context).unfocus();
                  await _saveAndClose(editorController);
                },
              ),
              _EditorMetadataSection(
                args: _args,
                titleController: _titleController,
                titleFocusNode: _titleFocusNode,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _EditorViewportInset(
                  child: _EditorMainCard(
                    args: _args,
                    bodyController: _bodyController,
                    bodyFocusNode: _bodyFocusNode,
                    bodyScrollController: _bodyScrollController,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndClose(NoteEditorController controller) async {
    await controller.saveNow(queueSyncImmediately: true);

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
}

class _EditorViewportInset extends StatelessWidget {
  const _EditorViewportInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: math.max(keyboardInset, bottomSafeArea),
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Isolated Widgets & Sub-components
// -----------------------------------------------------------------------------

class _EditorAppBar extends ConsumerWidget {
  const _EditorAppBar({
    required this.args,
    required this.onBackTap,
    required this.onSaveTap,
  });

  final NoteEditorArgs args;
  final VoidCallback onBackTap;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final folderId =
        ref.watch(noteEditorControllerProvider(args).select((s) => s.folderId));
    final folder = ref.watch(
      notesControllerProvider.select(
        (state) => state.valueOrNull?.folderById(folderId),
      ),
    );
    final availableFolders = ref.watch(
      notesControllerProvider.select(
        (state) => state.valueOrNull?.folders ?? const <FolderModel>[],
      ),
    );

    final isPinned =
        ref.watch(noteEditorControllerProvider(args).select((s) => s.isPinned));
    final isFavorite = ref
        .watch(noteEditorControllerProvider(args).select((s) => s.isFavorite));
    final isArchived = ref
        .watch(noteEditorControllerProvider(args).select((s) => s.isArchived));
    final noteId =
        ref.watch(noteEditorControllerProvider(args).select((s) => s.noteId));
    final editorController =
        ref.read(noteEditorControllerProvider(args).notifier);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactWidth = screenWidth < 360;

    return Padding(
      key: const ValueKey('note-editor-app-bar'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            style: IconButton.styleFrom(
              backgroundColor: palette.surfacePrimary,
              minimumSize: const Size(42, 42),
              shape: const CircleBorder(),
              side: BorderSide(color: palette.borderSoft),
            ),
            icon: Icon(Icons.arrow_back_rounded,
                color: palette.textPrimary, size: 20),
          ),
          Expanded(
            child: Center(
              child: _EditorFolderPicker(
                label: folder?.displayName ?? 'Choose folder',
                colorKey: folder?.colorKey ?? 'personal',
                onTap: () => _showFolderSelector(
                  context,
                  ref,
                  args,
                  availableFolders,
                  folderId,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.surfacePrimary,
                shape: BoxShape.circle,
                border: Border.all(color: palette.borderSoft),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.more_horiz_rounded,
                  color: palette.textPrimary, size: 20),
            ),
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
                    message: 'You can restore it later from Trash.',
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
                  isPinned ? 'Unpin note' : 'Pin note',
                ),
              ),
              PopupMenuItem(
                value: 'favorite',
                child: Text(
                  isFavorite ? 'Remove favorite' : 'Mark favorite',
                ),
              ),
              if (noteId != null)
                PopupMenuItem(
                  value: isArchived ? 'unarchive' : 'archive',
                  child: Text(
                    isArchived ? 'Move to notes' : 'Archive',
                  ),
                ),
              if (noteId != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          if (isCompactWidth)
            IconButton(
              tooltip: 'Save',
              onPressed: onSaveTap,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(42, 42),
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.check_rounded,
                size: 20,
              ),
            )
          else
            FilledButton(
              onPressed: onSaveTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                minimumSize: const Size(64, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: Text(
                'Save',
                style: AppTypography.buttonLabel.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorMetadataSection extends ConsumerWidget {
  const _EditorMetadataSection({
    required this.args,
    required this.titleController,
    required this.titleFocusNode,
  });

  final NoteEditorArgs args;
  final TextEditingController titleController;
  final FocusNode titleFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final editorController =
        ref.read(noteEditorControllerProvider(args).notifier);

    final folderId =
        ref.watch(noteEditorControllerProvider(args).select((s) => s.folderId));
    final tags =
        ref.watch(noteEditorControllerProvider(args).select((s) => s.tags));
    final isPinned =
        ref.watch(noteEditorControllerProvider(args).select((s) => s.isPinned));
    final isFavorite = ref
        .watch(noteEditorControllerProvider(args).select((s) => s.isFavorite));
    final isArchived = ref
        .watch(noteEditorControllerProvider(args).select((s) => s.isArchived));
    final folder = ref.watch(
      notesControllerProvider.select(
        (state) => state.valueOrNull?.folderById(folderId),
      ),
    );
    final availableFolders = ref.watch(
      notesControllerProvider.select(
        (state) => state.valueOrNull?.folders ?? const <FolderModel>[],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        key: const ValueKey('note-editor-metadata-card'),
        height: 120,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(color: palette.borderPrimary),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextField(
              controller: titleController,
              focusNode: titleFocusNode,
              onChanged: editorController.updateTitle,
              maxLines: 1,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: 'Untitled note',
                counterText: '',
              ),
              maxLength: 120,
              style: AppTypography.titleLarge.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _EditorActionChip(
                    icon: Icons.folder_open_rounded,
                    label: folder?.displayName ?? 'Choose folder',
                    onTap: () => _showFolderSelector(
                      context,
                      ref,
                      args,
                      availableFolders,
                      folderId,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _EditorActionChip(
                    icon: Icons.sell_outlined,
                    label: tags.isEmpty ? 'Add tags' : '${tags.length} tags',
                    onTap: () => _showTagSelector(
                      context,
                      ref,
                      args,
                      tags,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _EditorHeaderSaveStatusChip(args: args),
                  if (isPinned) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const _StatusBadge(
                      icon: Icons.push_pin_rounded,
                      label: 'Pinned',
                    ),
                  ],
                  if (isFavorite) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const _StatusBadge(
                      icon: Icons.star_rounded,
                      label: 'Favorite',
                    ),
                  ],
                  if (isArchived) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const _StatusBadge(
                      icon: Icons.archive_rounded,
                      label: 'Archived',
                    ),
                  ],
                  for (final tag in tags) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _TagBadge(label: '#$tag'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorMainCard extends ConsumerWidget {
  const _EditorMainCard({
    required this.args,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.bodyScrollController,
  });

  final NoteEditorArgs args;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final ScrollController bodyScrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final editorController =
        ref.read(noteEditorControllerProvider(args).notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      child: Container(
        key: const ValueKey('note-editor-main-card'),
        decoration: BoxDecoration(
          color: palette.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.formCard),
          border: Border.all(color: palette.borderPrimary),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NoteEditorToolbar(
              onBoldTap: () => _applyInlineWrap(
                bodyController,
                bodyFocusNode,
                editorController,
                prefix: '**',
                suffix: '**',
                placeholder: 'bold',
              ),
              onItalicTap: () => _applyInlineWrap(
                bodyController,
                bodyFocusNode,
                editorController,
                prefix: '_',
                suffix: '_',
                placeholder: 'italic',
              ),
              onChecklistTap: () => _applyLinePrefix(
                bodyController,
                bodyFocusNode,
                editorController,
                '- [ ] ',
              ),
              onBulletTap: () => _applyLinePrefix(
                bodyController,
                bodyFocusNode,
                editorController,
                '- ',
              ),
              onNumberedTap: () => _applyNumberedList(
                bodyController,
                bodyFocusNode,
                editorController,
              ),
              onHeadingTap: () => _applyLinePrefix(
                bodyController,
                bodyFocusNode,
                editorController,
                '## ',
              ),
              onQuoteTap: () => _applyLinePrefix(
                bodyController,
                bodyFocusNode,
                editorController,
                '> ',
              ),
              onTagTap: () => _showTagSelector(
                context,
                ref,
                args,
                ref.read(noteEditorControllerProvider(args)).tags,
              ),
            ),
            Divider(height: 1, color: palette.borderSoft),
            Expanded(
              child: TextField(
                key: const ValueKey('note-editor-body-field'),
                controller: bodyController,
                focusNode: bodyFocusNode,
                scrollController: bodyScrollController,
                onChanged: editorController.updateContent,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textAlignVertical: TextAlignVertical.top,
                scrollPadding: const EdgeInsets.only(bottom: 12),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: 'Start writing...',
                  hintStyle: AppTypography.bodyLarge.copyWith(
                    color: palette.textPlaceholder,
                    height: 1.7,
                  ),
                ),
                style: AppTypography.bodyLarge.copyWith(
                  height: 1.7,
                ),
              ),
            ),
            Divider(height: 1, color: palette.borderSoft),
            _EditorBottomStatsRow(args: args),
          ],
        ),
      ),
    );
  }
}

class _EditorBottomStatsRow extends ConsumerWidget {
  const _EditorBottomStatsRow({required this.args});
  final NoteEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Container(
        height: 24,
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _EditorWordCountChip(args: args),
              const SizedBox(width: AppSpacing.sm),
              _EditorReadTimeChip(args: args),
              const SizedBox(width: AppSpacing.sm),
              _EditorFooterSaveStatusChip(args: args),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pure Helpers & State Mapping
// -----------------------------------------------------------------------------

String _saveLabelFromState({
  required bool isSaving,
  required bool hasChanges,
  required DateTime? lastSavedAt,
  required bool isSyncing,
  required String? lastError,
  required SyncErrorType? lastErrorType,
}) {
  if (isSaving || hasChanges) {
    return 'Saving locally...';
  }

  if (isSyncing) {
    return 'Syncing...';
  }

  if (lastError != null) {
    return switch (lastErrorType) {
      SyncErrorType.noInternet ||
      SyncErrorType.dns ||
      SyncErrorType.tls ||
      SyncErrorType.timeout ||
      SyncErrorType.serverUnreachable =>
        'Offline - will sync later',
      _ => 'Sync failed - retrying',
    };
  }

  if (lastSavedAt == null) {
    return 'Autosave ready';
  }

  return 'Saved ${DateFormatter.formatRelative(lastSavedAt)}';
}

IconData _saveIconFromState({
  required bool isSaving,
  required bool hasChanges,
  required bool isSyncing,
  required String? lastError,
}) {
  if (isSaving || hasChanges) {
    return Icons.save_outlined;
  }

  if (isSyncing) {
    return Icons.cloud_sync_outlined;
  }

  if (lastError != null) {
    return Icons.cloud_off_outlined;
  }

  return Icons.cloud_done_outlined;
}

void _applyInlineWrap(
  TextEditingController controller,
  FocusNode focusNode,
  NoteEditorController editorController, {
  required String prefix,
  required String suffix,
  required String placeholder,
}) {
  final value = controller.value;
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
  _setBodyText(
    controller,
    focusNode,
    editorController,
    updatedText,
    updatedSelection,
  );
}

void _applyLinePrefix(
  TextEditingController controller,
  FocusNode focusNode,
  NoteEditorController editorController,
  String prefix,
) {
  _applyLineTransform(controller, focusNode, editorController, (lines) {
    return lines
        .map((line) => '$prefix${line.trimLeft()}')
        .toList(growable: false);
  });
}

void _applyNumberedList(
  TextEditingController controller,
  FocusNode focusNode,
  NoteEditorController editorController,
) {
  _applyLineTransform(controller, focusNode, editorController, (lines) {
    return [
      for (var index = 0; index < lines.length; index += 1)
        '${index + 1}. ${lines[index].trimLeft()}',
    ];
  });
}

void _applyLineTransform(
  TextEditingController controller,
  FocusNode focusNode,
  NoteEditorController editorController,
  List<String> Function(List<String> lines) transform,
) {
  final value = controller.value;
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
    focusNode,
    editorController,
    updatedText,
    TextSelection.collapsed(offset: blockStart + updatedBlock.length),
  );
}

void _setBodyText(
  TextEditingController controller,
  FocusNode focusNode,
  NoteEditorController editorController,
  String text,
  TextSelection selection,
) {
  controller.value = TextEditingValue(
    text: text,
    selection: selection,
  );
  editorController.updateContent(text);
  focusNode.requestFocus();
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

// -----------------------------------------------------------------------------
// Selection Dialogs & Overlay Builders
// -----------------------------------------------------------------------------

Future<void> _showFolderSelector(
  BuildContext context,
  WidgetRef ref,
  NoteEditorArgs args,
  List<FolderModel> folders,
  String? selectedFolderId,
) async {
  final editorController =
      ref.read(noteEditorControllerProvider(args).notifier);
  final palette = context.palette;
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: palette.surfacePrimary,
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
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: folderVisualsFor(folder.colorKey).backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      folderVisualsFor(folder.colorKey).icon,
                      color: folderVisualsFor(folder.colorKey).accentColor,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    folder.displayName,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: selectedFolderId == folder.id
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
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
  NoteEditorArgs args,
  List<String> currentTags,
) async {
  final notesState = ref.read(notesControllerProvider).valueOrNull;
  final editorController =
      ref.read(noteEditorControllerProvider(args).notifier);
  final availableTags = notesState?.tags ?? const [];
  final selectedTags = currentTags.toSet();

  final result = await showDialog<List<String>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final palette = context.palette;
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
                      selectedColor:
                          AppColors.brandPrimary.withValues(alpha: 0.14),
                      checkmarkColor: AppColors.brandPrimary,
                      labelStyle: TextStyle(
                        color: selectedTags.contains(tag.label)
                            ? AppColors.brandPrimary
                            : palette.textPrimary,
                        fontWeight: selectedTags.contains(tag.label)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: selectedTags.contains(tag.label)
                              ? AppColors.brandPrimary
                              : palette.borderSoft,
                        ),
                      ),
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

// -----------------------------------------------------------------------------
// Presentational Elements (Chips, Picker, Badges)
// -----------------------------------------------------------------------------

class _EditorFolderPicker extends StatelessWidget {
  const _EditorFolderPicker({
    required this.label,
    required this.colorKey,
    required this.onTap,
  });

  final String label;
  final String colorKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visuals = folderVisualsFor(colorKey);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth.clamp(0, 180).toDouble(),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: palette.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: palette.borderSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    visuals.icon,
                    size: 16,
                    color: visuals.accentColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditorMetaChip extends StatelessWidget {
  const _EditorMetaChip({
    required this.label,
    this.icon,
    this.emphasized = false,
    this.width,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.brandPrimary.withValues(alpha: 0.08)
            : palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: width == null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 13,
                    color: emphasized
                        ? AppColors.brandPrimary
                        : palette.textSecondary,
                  ),
                  const SizedBox(width: 4),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: emphasized
                          ? AppColors.brandPrimary
                          : palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: width,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 13,
                      color: emphasized
                          ? AppColors.brandPrimary
                          : palette.textSecondary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: emphasized
                            ? AppColors.brandPrimary
                            : palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EditorActionChip extends StatelessWidget {
  const _EditorActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.brandPrimary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorInfoChip extends StatelessWidget {
  const _EditorInfoChip({
    required this.icon,
    required this.label,
    this.width,
    this.chipKey,
  });

  final IconData icon;
  final String label;
  final double? width;
  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      key: chipKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfacePrimary.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: width == null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: palette.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: width,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: palette.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EditorHeaderSaveStatusChip extends ConsumerWidget {
  const _EditorHeaderSaveStatusChip({required this.args});

  final NoteEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _watchEditorStatus(ref, args);

    return _EditorInfoChip(
      chipKey: const ValueKey('note-editor-header-status'),
      icon: status.icon,
      label: status.label,
      width: 176,
    );
  }
}

class _EditorFooterSaveStatusChip extends ConsumerWidget {
  const _EditorFooterSaveStatusChip({required this.args});

  final NoteEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _watchEditorStatus(ref, args);

    return _EditorMetaChip(
      label: status.label,
      icon: status.icon,
      emphasized: true,
      width: 176,
    );
  }
}

class _EditorWordCountChip extends ConsumerWidget {
  const _EditorWordCountChip({required this.args});

  final NoteEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(
      noteEditorControllerProvider(args).select((state) => state.content),
    );

    return _EditorMetaChip(label: '${_countWords(content)} words');
  }
}

class _EditorReadTimeChip extends ConsumerWidget {
  const _EditorReadTimeChip({required this.args});

  final NoteEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(
      noteEditorControllerProvider(args).select((state) => state.content),
    );

    return _EditorMetaChip(label: DateFormatter.estimateReadTime(content));
  }
}

class _EditorStatusVisual {
  const _EditorStatusVisual({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

_EditorStatusVisual _watchEditorStatus(WidgetRef ref, NoteEditorArgs args) {
  final (:isSaving, :hasChanges, :lastSavedAt) = ref.watch(
    noteEditorControllerProvider(args).select(
      (state) => (
        isSaving: state.isSaving,
        hasChanges: state.hasChanges,
        lastSavedAt: state.lastSavedAt,
      ),
    ),
  );
  final (:isSyncing, :lastError, :lastErrorType) = ref.watch(
    syncControllerProvider.select(
      (state) => (
        isSyncing: state.isSyncing,
        lastError: state.lastError,
        lastErrorType: state.lastErrorType,
      ),
    ),
  );

  return _EditorStatusVisual(
    label: _saveLabelFromState(
      isSaving: isSaving,
      hasChanges: hasChanges,
      lastSavedAt: lastSavedAt,
      isSyncing: isSyncing,
      lastError: lastError,
      lastErrorType: lastErrorType,
    ),
    icon: _saveIconFromState(
      isSaving: isSaving,
      hasChanges: hasChanges,
      isSyncing: isSyncing,
      lastError: lastError,
    ),
  );
}

int _countWords(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) {
    return 0;
  }
  return trimmed.split(RegExp(r'\s+')).length;
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border:
            Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.brandPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
