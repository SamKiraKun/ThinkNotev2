import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../notes/data/models/notes_store_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';

class ImportExportScreen extends ConsumerWidget {
  const ImportExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(title: const Text('Import and export')),
      body: SafeArea(
        child: notesAsync.when(
          data: (notesState) => ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              _ActionCard(
                icon: Icons.ios_share_rounded,
                title: 'Export JSON',
                message:
                    'Copy a validated JSON backup of notes, folders, tags, searches, and preferences.',
                actionLabel: 'Copy backup',
                onPressed: () => _exportJson(context, notesState.toStore()),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ActionCard(
                icon: Icons.content_paste_go_rounded,
                title: 'Import JSON',
                message:
                    'Paste a backup JSON object from the clipboard. Import replaces current local data.',
                actionLabel: 'Import from clipboard',
                isDestructive: true,
                onPressed: () => _importFromClipboard(context, ref),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Unable to load import/export tools.',
              style: AppTypography.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, NotesStoreModel store) async {
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(
      ClipboardData(text: encoder.convert(store.toJson())),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup JSON copied to clipboard.')),
      );
    }
  }

  Future<void> _importFromClipboard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Replace local data?',
        message:
            'Importing from JSON replaces notes, folders, tags, searches, and preferences on this device.',
        confirmLabel: 'Import',
        isDestructive: true,
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = clipboard?.text;
      if (raw == null || raw.trim().isEmpty) {
        throw const FormatException('Clipboard is empty.');
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backup root must be a JSON object.');
      }

      final store = NotesStoreModel.fromJson(decoded);
      await ref.read(notesControllerProvider.notifier).replaceStore(store);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup imported.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $error')),
        );
      }
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isDestructive ? AppColors.textDanger : AppColors.brandPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.formCard),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
