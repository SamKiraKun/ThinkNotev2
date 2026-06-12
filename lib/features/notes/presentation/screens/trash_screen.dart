import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../notes/presentation/widgets/note_card.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;
    final syncEnabled = AppEnv.enableExperimentalSync;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (!syncEnabled)
            TextButton(
              onPressed: () => _confirmEmptyTrash(context, ref),
              child: Text(
                'Empty',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: notesAsync.when(
          data: (notesState) {
            if (notesState.trashedNotes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: AppEmptyState(
                  icon: Icons.delete_outline_rounded,
                  title: 'Trash is empty',
                  message: syncEnabled
                      ? 'Deleted notes stay here until you restore them. Permanent cloud purge is not part of this release.'
                      : 'Deleted notes will appear here until you restore or remove them forever.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              itemCount: notesState.trashedNotes.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.noteCardGap),
              itemBuilder: (context, index) {
                final note = notesState.trashedNotes[index];
                return NoteCard(
                  note: note,
                  folder: notesState.folderById(note.folderId),
                  subtitle:
                      'Deleted ${DateFormatter.formatRelative(note.deletedAt ?? note.updatedAt)}',
                  previewLines: notesState.preferences.previewLines,
                  onTap: () {},
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'restore') {
                        ref
                            .read(notesControllerProvider.notifier)
                            .restore(note.id);
                      } else if (!syncEnabled && value == 'delete') {
                        _confirmPermanentDelete(context, ref, note.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'restore',
                        child: Text('Restore'),
                      ),
                      if (!syncEnabled)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete forever'),
                        ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const AppLoadingState(
            title: 'Loading trash',
            message: 'Checking notes that can still be restored.',
          ),
          error: (error, _) => AppErrorState(
            title: 'Unable to load trash',
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () async {
              await ref.read(notesControllerProvider.notifier).refresh();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    String noteId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Delete forever?',
        message: 'This note will be removed permanently from this device.',
        confirmLabel: 'Delete forever',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      await ref
          .read(notesControllerProvider.notifier)
          .deletePermanently(noteId);
    }
  }

  Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Empty trash?',
        message: 'Every note in Trash will be deleted permanently.',
        confirmLabel: 'Empty trash',
        isDestructive: true,
      ),
    );
    if (confirmed == true) {
      await ref.read(notesControllerProvider.notifier).emptyTrash();
      if (context.mounted) {
        context.pop();
      }
    }
  }
}
