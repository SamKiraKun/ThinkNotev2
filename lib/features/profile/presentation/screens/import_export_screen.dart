import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../notes/data/models/notes_store_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  int _currentTab = 0; // 0 = Export, 1 = Import

  // Export State
  String? _generatedJson;
  String? _exportFilename;
  String? _exportFilePath;
  String? _exportSizeString;
  bool _isSavedLocally = false;

  // Import State
  final _importController = TextEditingController();
  NotesStoreModel? _validatedStore;
  String? _validationError;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesControllerProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        title: const Text('Import and export'),
        elevation: 0,
      ),
      body: SafeArea(
        child: notesAsync.when(
          data: (notesState) => ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              _buildTabSelector(context),
              const SizedBox(height: AppSpacing.xxl),
              if (_currentTab == 0)
                _buildExportTab(context, notesState.toStore())
              else
                _buildImportTab(context),
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

  Widget _buildTabSelector(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentTab = 0),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: _currentTab == 0 ? AppColors.brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Export Data',
                  style: AppTypography.bodyLarge.copyWith(
                    color: _currentTab == 0 ? Colors.white : palette.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentTab = 1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: _currentTab == 1 ? AppColors.brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Import Data',
                  style: AppTypography.bodyLarge.copyWith(
                    color: _currentTab == 1 ? Colors.white : palette.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportTab(BuildContext context, NotesStoreModel store) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Security Warning
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encrypted Backup Requirement',
                      style: AppTypography.titleSmall.copyWith(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'ThinkNote now exports backup packages as encrypted files only. Save the generated file in a location you control and keep the password separate from the file itself.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Statistics Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: palette.surfacePrimary,
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            boxShadow: AppShadows.softCard,
            border: Border.all(color: palette.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workspace Statistics', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Notes', store.notes.length),
                  _buildStatItem('Folders', store.folders.length),
                  _buildStatItem('Tags', store.tags.length),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => _exportPressed(store),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Generate Backup JSON'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_generatedJson != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: BorderRadius.circular(AppRadius.formCard),
              boxShadow: AppShadows.softCard,
              border: Border.all(color: palette.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Backup Package Ready', style: AppTypography.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _exportSizeString ?? '0 KB',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Filename: $_exportFilename',
                  style: AppTypography.bodyMedium.copyWith(
                    fontFamily: 'monospace',
                    color: palette.textSecondary,
                  ),
                ),
                if (_exportFilePath != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Saved at: $_exportFilePath',
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _saveToLocalFile,
                  icon: Icon(_isSavedLocally ? Icons.check : Icons.save_alt_rounded),
                  label: Text(_isSavedLocally ? 'Saved File' : 'Save Encrypted Backup File'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: _isSavedLocally ? Colors.green : AppColors.brandPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: AppTypography.headline.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildImportTab(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hazard Notice
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.textDanger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            border: Border.all(color: AppColors.textDanger.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.report_problem_rounded, color: AppColors.textDanger, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restore Carefully',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textDanger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Restoring from a backup file replaces all local notes, tags, and settings on this device. This operation is permanent. Export a fresh encrypted backup before restoring older data.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textDanger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Paste Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: palette.surfacePrimary,
            borderRadius: BorderRadius.circular(AppRadius.formCard),
            boxShadow: AppShadows.softCard,
            border: Border.all(color: palette.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Paste Backup Payload', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Load the latest backup file saved by ThinkNote or paste a trusted backup package manually.',
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _importController,
                maxLines: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: '{\n  "notes": [...],\n  "folders": [...],\n  "tags": [...]\n}',
                  hintStyle: TextStyle(color: palette.textPlaceholder),
                  filled: true,
                  fillColor: palette.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: palette.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: palette.borderSoft),
                  ),
                ),
                onChanged: (_) {
                  if (_validatedStore != null || _validationError != null) {
                    setState(() {
                      _validatedStore = null;
                      _validationError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadLatestLocalBackup,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Load Latest Backup'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: AppColors.brandPrimary,
                        side: const BorderSide(color: AppColors.brandPrimary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _validateImport,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Validate Backup'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.brandPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Validation Feedback Banners
        if (_validationError != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.textDanger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.formCard),
              border: Border.all(color: AppColors.textDanger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.textDanger, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Invalid Backup: $_validationError',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textDanger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_validatedStore != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.formCard),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Backup verified successfully!',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Payload contains: ${_validatedStore!.notes.length} notes, ${_validatedStore!.folders.length} folders, ${_validatedStore!.tags.length} tags.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _performImport,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Overwrite & Restore Workspace'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.textDanger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<String> _encryptBackup(String plaintextJson, String password) async {
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final secretKey = SecretKey(keyBytes);
    final cipher = AesGcm.with256bits();
    
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    
    final secretBox = await cipher.encrypt(
      utf8.encode(plaintextJson),
      secretKey: secretKey,
      nonce: nonce,
    );
    
    final payload = {
      'encrypted': true,
      'ciphertext': base64UrlEncode(secretBox.cipherText),
      'nonce': base64UrlEncode(secretBox.nonce),
      'mac': base64UrlEncode(secretBox.mac.bytes),
    };
    return jsonEncode(payload);
  }

  Future<String> _decryptBackup(String encryptedJson, String password) async {
    final Map<String, dynamic> decoded = jsonDecode(encryptedJson);
    if (decoded['encrypted'] != true) {
      throw const FormatException('This backup is not encrypted.');
    }
    
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final secretKey = SecretKey(keyBytes);
    final cipher = AesGcm.with256bits();
    
    final secretBox = SecretBox(
      base64Url.decode(decoded['ciphertext'] as String),
      nonce: base64Url.decode(decoded['nonce'] as String),
      mac: Mac(base64Url.decode(decoded['mac'] as String)),
    );
    
    final clearBytes = await cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return utf8.decode(clearBytes);
  }

  Future<void> _exportPressed(NotesStoreModel store) async {
    final passwordChoice = await _showPasswordPromptDialog(
      title: 'Secure Backup',
      message: 'Choose a password to encrypt this backup. This prevents unauthorized access to your notes if the backup package is exposed.',
      buttonLabel: 'Encrypt & Export',
      isExport: true,
    );

    if (passwordChoice == null) {
      return;
    }

    await _generateExport(store, passwordChoice);
  }

  Future<void> _generateExport(NotesStoreModel store, String? password) async {
    const encoder = JsonEncoder.withIndent('  ');
    final jsonText = encoder.convert(store.toJson());
    
    String finalOutput;
    bool isEncrypted = false;
    
    if (password != null) {
      finalOutput = await _encryptBackup(jsonText, password);
      isEncrypted = true;
    } else {
      finalOutput = jsonText;
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final bytes = utf8.encode(finalOutput);
    final sizeKb = bytes.length / 1024;

    setState(() {
      _generatedJson = finalOutput;
      _exportFilename = isEncrypted 
          ? 'thinknote_backup_$timestamp.enc.json'
          : 'thinknote_backup_$timestamp.json';
      _exportSizeString = '${sizeKb.toStringAsFixed(2)} KB';
      _exportFilePath = null;
      _isSavedLocally = false;
    });
  }

  Future<void> _saveToLocalFile() async {
    if (_generatedJson == null || _exportFilename == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${_exportFilename!}');
      await file.writeAsString(_generatedJson!);

      setState(() {
        _exportFilePath = file.path;
        _isSavedLocally = true;
      });
      _showSnack('Backup file saved locally.');
    } catch (e) {
      _showSnack('Failed to save file: $e');
    }
  }

  Future<void> _loadLatestLocalBackup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupFiles = directory.listSync().whereType<File>().where((file) {
        final name = file.uri.pathSegments.isEmpty
            ? file.path
            : file.uri.pathSegments.last;
        return name.startsWith('thinknote_backup_') &&
            (name.endsWith('.enc.json') || name.endsWith('.json'));
      }).toList();

      if (backupFiles.isEmpty) {
        _showSnack('No saved backup files were found on this device.');
        return;
      }

      backupFiles.sort(
        (left, right) => right
            .lastModifiedSync()
            .compareTo(left.lastModifiedSync()),
      );

      final latestFile = backupFiles.first;
      _importController.text = await latestFile.readAsString();
      await _validateImport();
      _showSnack('Loaded ${latestFile.uri.pathSegments.last}.');
    } catch (error) {
      _showSnack('Failed to load the latest backup: $error');
    }
  }

  Future<void> _validateImport() async {
    final raw = _importController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _validationError = 'Input field is empty.';
        _validatedStore = null;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Root element must be a JSON object.');
      }

      if (decoded['encrypted'] == true) {
        final password = await _showPasswordPromptDialog(
          title: 'Decryption Required',
          message: 'This backup is secured with a password. Enter the password to decrypt it.',
          buttonLabel: 'Decrypt & Validate',
        );
        if (password == null) {
          return; // User cancelled
        }
        
        final decryptedRaw = await _decryptBackup(raw, password);
        final decryptedDecoded = jsonDecode(decryptedRaw);
        if (decryptedDecoded is! Map<String, dynamic>) {
          throw const FormatException('Decrypted root element must be a JSON object.');
        }
        
        final store = NotesStoreModel.fromJson(decryptedDecoded);
        setState(() {
          _validatedStore = store;
          _validationError = null;
        });
        _showSnack('Backup decrypted and validated successfully.');
      } else {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => const AppConfirmationDialog(
            title: 'Unencrypted Backup',
            message: 'This backup package is not encrypted. Importing unencrypted data is allowed, but please ensure the source is trusted.',
            confirmLabel: 'Proceed',
            isDestructive: false,
          ),
        );
        if (proceed != true) return;

        final store = NotesStoreModel.fromJson(decoded);
        setState(() {
          _validatedStore = store;
          _validationError = null;
        });
      }
    } catch (error) {
      setState(() {
        _validationError = 'Incorrect password or corrupted backup package.';
        _validatedStore = null;
      });
    }
  }

  Future<String?> _showPasswordPromptDialog({
    required String title,
    required String message,
    required String buttonLabel,
    bool isExport = false,
  }) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    return showDialog<String>(
      context: context,
      builder: (context) {
        final palette = context.palette;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: palette.surfacePrimary,
              title: Text(title, style: AppTypography.titleLarge),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(message, style: AppTypography.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: controller,
                      obscureText: obscure,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: isExport ? 'Min 4 characters' : 'Enter password',
                        filled: true,
                        fillColor: palette.surfaceSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(color: palette.borderSoft),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password cannot be empty.';
                        }
                        if (isExport && value.trim().length < 4) {
                          return 'Password must be at least 4 characters.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.of(context).pop(controller.text.trim());
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                  ),
                  child: Text(buttonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performImport() async {
    if (_validatedStore == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Overwrite all data?',
        message:
            'This replaces all notes, folders, tags, and settings on this device. This operation is permanent.',
        confirmLabel: 'Confirm Overwrite',
        isDestructive: true,
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(notesControllerProvider.notifier).replaceStore(_validatedStore!);
      _importController.clear();
      setState(() {
        _validatedStore = null;
        _validationError = null;
      });
      _showSnack('Backup successfully restored.');
    } catch (error) {
      _showSnack('Failed to restore backup: $error');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
