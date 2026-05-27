import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../controllers/notes_controller.dart';
import '../widgets/note_card.dart';

class ArchivedNotesScreen extends ConsumerWidget {
  const ArchivedNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        title: const Text('Archive'),
      ),
      body: SafeArea(
        child: notesAsync.when(
          data: (notesState) {
            if (notesState.archivedNotes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: AppEmptyState(
                  icon: Icons.archive_outlined,
                  title: 'Archive is empty',
                  message:
                      'Archived notes stay out of your active workspace until you move them back.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              itemCount: notesState.archivedNotes.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.noteCardGap),
              itemBuilder: (context, index) {
                final note = notesState.archivedNotes[index];
                return NoteCard(
                  note: note,
                  folder: notesState.folderById(note.folderId),
                  subtitle:
                      'Archived ${DateFormatter.formatRelative(note.updatedAt)}',
                  previewLines: notesState.preferences.previewLines,
                  onTap: () {
                    context.push(
                      RouteNames.editor,
                      extra: <String, dynamic>{'noteId': note.id},
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'unarchive') {
                        ref
                            .read(notesControllerProvider.notifier)
                            .unarchive(note.id);
                      } else if (value == 'trash') {
                        _confirmMoveToTrash(context, ref, note.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'unarchive',
                        child: Text('Move to notes'),
                      ),
                      PopupMenuItem(
                        value: 'trash',
                        child: Text('Move to Trash'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Unable to load Archive.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textDanger,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmMoveToTrash(
    BuildContext context,
    WidgetRef ref,
    String noteId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Move archived note to Trash?',
        message: 'You can restore it later from Trash.',
        confirmLabel: 'Move to Trash',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      await ref.read(notesControllerProvider.notifier).moveToTrash(noteId);
    }
  }
}
