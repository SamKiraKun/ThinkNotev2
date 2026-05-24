import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/dependency_injection.dart';
import '../../../../core/utils/debouncer.dart';
import '../../domain/repositories/notes_repository.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import 'notes_controller.dart';

class NoteEditorArgs {
  const NoteEditorArgs({
    this.noteId,
    this.initialFolderId,
  });

  final String? noteId;
  final String? initialFolderId;
}

class NoteEditorState {
  const NoteEditorState({
    required this.noteId,
    required this.title,
    required this.content,
    required this.folderId,
    required this.tags,
    required this.isPinned,
    required this.isFavorite,
    required this.isArchived,
    required this.isLoading,
    required this.isSaving,
    required this.hasChanges,
    required this.errorMessage,
    this.lastSavedAt,
  });

  factory NoteEditorState.loading({String? initialFolderId}) {
    return NoteEditorState(
      noteId: null,
      title: '',
      content: '',
      folderId: initialFolderId,
      tags: const <String>[],
      isPinned: false,
      isFavorite: false,
      isArchived: false,
      isLoading: true,
      isSaving: false,
      hasChanges: false,
      errorMessage: null,
    );
  }

  final String? noteId;
  final String title;
  final String content;
  final String? folderId;
  final List<String> tags;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isLoading;
  final bool isSaving;
  final bool hasChanges;
  final String? errorMessage;
  final DateTime? lastSavedAt;

  bool get hasMeaningfulContent {
    return title.trim().isNotEmpty || content.trim().isNotEmpty;
  }

  NoteEditorState copyWith({
    Object? noteId = _editorSentinel,
    String? title,
    String? content,
    Object? folderId = _editorSentinel,
    List<String>? tags,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    bool? isLoading,
    bool? isSaving,
    bool? hasChanges,
    Object? errorMessage = _editorSentinel,
    Object? lastSavedAt = _editorSentinel,
  }) {
    return NoteEditorState(
      noteId:
          identical(noteId, _editorSentinel) ? this.noteId : noteId as String?,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: identical(folderId, _editorSentinel)
          ? this.folderId
          : folderId as String?,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasChanges: hasChanges ?? this.hasChanges,
      errorMessage: identical(errorMessage, _editorSentinel)
          ? this.errorMessage
          : errorMessage as String?,
      lastSavedAt: identical(lastSavedAt, _editorSentinel)
          ? this.lastSavedAt
          : lastSavedAt as DateTime?,
    );
  }
}

final noteEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<NoteEditorController, NoteEditorState, NoteEditorArgs>((ref, args) {
  return NoteEditorController(ref, args);
});

class NoteEditorController extends StateNotifier<NoteEditorState> {
  NoteEditorController(this._ref, this._args)
      : _repository = _ref.read(notesRepositoryProvider),
        _debouncer = Debouncer(const Duration(milliseconds: 450)),
        super(NoteEditorState.loading(initialFolderId: _args.initialFolderId)) {
    _load();
  }

  final Ref _ref;
  final NoteEditorArgs _args;
  final NotesRepository _repository;
  final Debouncer _debouncer;

  Future<void> _load() async {
    final noteId = _args.noteId;
    if (noteId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final existing = await _repository.getNoteById(noteId);
    if (existing == null) {
      state = state.copyWith(isLoading: false, noteId: null);
      return;
    }

    state = NoteEditorState(
      noteId: existing.id,
      title: existing.title,
      content: existing.content,
      folderId: existing.folderId ?? _args.initialFolderId,
      tags: existing.tags,
      isPinned: existing.isPinned,
      isFavorite: existing.isFavorite,
      isArchived: existing.isArchived,
      isLoading: false,
      isSaving: false,
      hasChanges: false,
      errorMessage: null,
      lastSavedAt: existing.updatedAt,
    );
  }

  void updateTitle(String value) {
    state = state.copyWith(
      title: value,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void updateContent(String value) {
    state = state.copyWith(
      content: value,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void setFolder(String folderId) {
    state = state.copyWith(
      folderId: folderId,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void togglePinned() {
    state = state.copyWith(
      isPinned: !state.isPinned,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void toggleFavorite() {
    state = state.copyWith(
      isFavorite: !state.isFavorite,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  Future<void> archiveCurrentNote() async {
    final noteId = state.noteId;
    if (noteId == null) {
      return;
    }
    await _repository.archiveNote(noteId);
    _scheduleSync();
    state = state.copyWith(isArchived: true, isPinned: false);
    _ref.invalidate(notesControllerProvider);
  }

  Future<void> unarchiveCurrentNote() async {
    final noteId = state.noteId;
    if (noteId == null) {
      return;
    }
    await _repository.unarchiveNote(noteId);
    _scheduleSync();
    state = state.copyWith(isArchived: false);
    _ref.invalidate(notesControllerProvider);
  }

  void replaceTags(List<String> tags) {
    state = state.copyWith(
      tags: tags,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void appendTemplate(String template) {
    final prefix =
        state.content.isEmpty || state.content.endsWith('\n') ? '' : '\n';
    updateContent('${state.content}$prefix$template');
  }

  Future<void> saveNow() async {
    await _debouncer.flush();
    await _persist();
  }

  Future<void> deleteCurrentNote() async {
    final noteId = state.noteId;
    if (noteId == null) {
      return;
    }
    await _repository.moveToTrash(noteId);
    _scheduleSync();
    _ref.invalidate(notesControllerProvider);
  }

  void _scheduleSave() {
    _debouncer.run(_persist);
  }

  Future<void> _persist() async {
    if (state.isLoading || !state.hasChanges) {
      return;
    }

    if (state.noteId == null && !state.hasMeaningfulContent) {
      state = state.copyWith(hasChanges: false, errorMessage: null);
      return;
    }

    state = state.copyWith(
      isSaving: true,
      errorMessage: null,
    );

    try {
      final saved = await _repository.saveNote(
        NoteDraft(
          id: state.noteId,
          title: state.title,
          content: state.content,
          folderId: state.folderId,
          tags: state.tags,
          isPinned: state.isPinned,
          isFavorite: state.isFavorite,
        ),
      );

      if (saved == null) {
        state = state.copyWith(
          isSaving: false,
          hasChanges: false,
        );
        return;
      }

      state = state.copyWith(
        noteId: saved.id,
        title: saved.title,
        content: saved.content,
        folderId: saved.folderId,
        tags: saved.tags,
        isPinned: saved.isPinned,
        isFavorite: saved.isFavorite,
        isArchived: saved.isArchived,
        isSaving: false,
        hasChanges: false,
        lastSavedAt: saved.updatedAt,
      );
      _scheduleSync();
      _ref.invalidate(notesControllerProvider);
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save this note right now.',
      );
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _scheduleSync() {
    unawaited(_ref.read(syncControllerProvider.notifier).scheduleSync());
  }
}

const Object _editorSentinel = Object();
