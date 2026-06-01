import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../bootstrap/dependency_injection.dart';
import '../../../../core/utils/debouncer.dart';
import '../../data/models/note_model.dart';
import '../../domain/repositories/notes_repository.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import 'notes_controller.dart';

class NoteEditorArgs {
  const NoteEditorArgs({
    this.noteId,
    this.initialFolderId,
    this.initialNote,
  });

  final String? noteId;
  final String? initialFolderId;
  final NoteModel? initialNote;
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
  NoteEditorController(this._ref, NoteEditorArgs args)
      : _args = args,
        _repository = _ref.read(notesRepositoryProvider),
        _debouncer = Debouncer(const Duration(milliseconds: 450)),
        _syncDebouncer = Debouncer(const Duration(milliseconds: 1200)),
        _draftNoteId = args.noteId ?? const Uuid().v4(),
        super(
          args.initialNote == null
              ? NoteEditorState.loading(initialFolderId: args.initialFolderId)
              : _stateFromNote(
                  args.initialNote,
                  initialFolderId: args.initialFolderId,
                ),
        ) {
    _load();
  }

  final Ref _ref;
  final NoteEditorArgs _args;
  final NotesRepository _repository;
  final Debouncer _debouncer;
  final Debouncer _syncDebouncer;
  final String _draftNoteId;
  Future<void>? _persistInFlight;
  bool _persistAgainAfterInFlight = false;
  int _editRevision = 0;

  Future<void> _load() async {
    final noteId = _args.noteId;
    if (noteId == null) {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    final revisionAtStart = _editRevision;
    final stopwatch = Stopwatch()..start();
    final existing = await _repository.getNoteById(noteId);
    stopwatch.stop();
    debugPrint(
      '[NoteEditorController] Loaded note $noteId in ${stopwatch.elapsedMilliseconds} ms.',
    );
    if (!mounted || _editRevision != revisionAtStart) {
      return;
    }

    if (existing == null) {
      if (_args.initialNote == null) {
        state = state.copyWith(isLoading: false, noteId: null);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    state = _stateFromNote(
      existing,
      initialFolderId: _args.initialFolderId,
    );
  }

  void updateTitle(String value) {
    if (!mounted) {
      return;
    }
    _markEdited();
    state = state.copyWith(
      title: value,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void updateContent(String value) {
    if (!mounted) {
      return;
    }
    _markEdited();
    state = state.copyWith(
      content: value,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void setFolder(String folderId) {
    if (!mounted) {
      return;
    }
    _markEdited();
    state = state.copyWith(
      folderId: folderId,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void togglePinned() {
    if (!mounted) {
      return;
    }
    _markEdited();
    state = state.copyWith(
      isPinned: !state.isPinned,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  void toggleFavorite() {
    if (!mounted) {
      return;
    }
    _markEdited();
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
    if (!mounted) {
      return;
    }
    _markEdited();
    state = state.copyWith(
      tags: tags,
      hasChanges: true,
      errorMessage: null,
    );
    _scheduleSave();
  }

  Future<void> saveNow({bool queueSyncImmediately = false}) async {
    if (!mounted) {
      return;
    }
    await _debouncer.flush();
    await _persistLatest();
    if (queueSyncImmediately) {
      _scheduleSyncNow();
    }
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
    _debouncer.run(_persistLatest);
  }

  Future<void> _persistLatest() {
    final inFlight = _persistInFlight;
    if (inFlight != null) {
      _persistAgainAfterInFlight = true;
      return inFlight;
    }

    final future = _drainPersistQueue();
    _persistInFlight = future.whenComplete(() {
      _persistInFlight = null;
    });
    return _persistInFlight!;
  }

  Future<void> _drainPersistQueue() async {
    do {
      _persistAgainAfterInFlight = false;
      await _persistSnapshot();
    } while (_persistAgainAfterInFlight && mounted);
  }

  Future<void> _persistSnapshot() async {
    if (!mounted) {
      return;
    }
    if (state.isLoading || !state.hasChanges) {
      return;
    }

    if (state.noteId == null && !state.hasMeaningfulContent) {
      state = state.copyWith(hasChanges: false, errorMessage: null);
      return;
    }

    final revisionAtStart = _editRevision;
    final draft = NoteDraft(
      id: state.noteId ?? _draftNoteId,
      title: state.title,
      content: state.content,
      folderId: state.folderId,
      tags: state.tags,
      isPinned: state.isPinned,
      isFavorite: state.isFavorite,
    );

    if (mounted) {
      state = state.copyWith(
        isSaving: true,
        errorMessage: null,
      );
    }

    try {
      final saved = await _repository.saveNote(draft);

      if (!mounted) {
        return;
      }

      if (saved == null) {
        final hasNewerEditorChanges = _editRevision != revisionAtStart;
        state = state.copyWith(
          isSaving: false,
          hasChanges: hasNewerEditorChanges,
        );
        if (hasNewerEditorChanges) {
          _scheduleSave();
        }
        return;
      }

      final hasNewerEditorChanges = _editRevision != revisionAtStart;
      final current = state;
      state = state.copyWith(
        noteId: saved.id,
        title: hasNewerEditorChanges ? current.title : saved.title,
        content: hasNewerEditorChanges ? current.content : saved.content,
        folderId: hasNewerEditorChanges ? current.folderId : saved.folderId,
        tags: hasNewerEditorChanges ? current.tags : saved.tags,
        isPinned: hasNewerEditorChanges ? current.isPinned : saved.isPinned,
        isFavorite:
            hasNewerEditorChanges ? current.isFavorite : saved.isFavorite,
        isArchived:
            hasNewerEditorChanges ? current.isArchived : saved.isArchived,
        isSaving: false,
        hasChanges: hasNewerEditorChanges,
        lastSavedAt: saved.updatedAt,
      );
      _scheduleSync();
      _ref.invalidate(notesControllerProvider);

      if (hasNewerEditorChanges) {
        _scheduleSave();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save this note right now.',
      );
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _syncDebouncer.dispose();
    super.dispose();
  }

  void _markEdited() {
    _editRevision += 1;
  }

  void _scheduleSync() {
    if (!mounted) {
      return;
    }
    _syncDebouncer.run(() {
      return _ref.read(syncControllerProvider.notifier).scheduleSync();
    });
  }

  void _scheduleSyncNow() {
    if (!mounted) {
      return;
    }
    unawaited(_ref.read(syncControllerProvider.notifier).scheduleSync());
  }
}

NoteEditorState _stateFromNote(
  NoteModel? note, {
  String? initialFolderId,
}) {
  if (note == null) {
    return NoteEditorState.loading(initialFolderId: initialFolderId).copyWith(
      isLoading: false,
    );
  }

  return NoteEditorState(
    noteId: note.id,
    title: note.title,
    content: note.content,
    folderId: note.folderId ?? initialFolderId,
    tags: note.tags,
    isPinned: note.isPinned,
    isFavorite: note.isFavorite,
    isArchived: note.isArchived,
    isLoading: false,
    isSaving: false,
    hasChanges: false,
    errorMessage: null,
    lastSavedAt: note.updatedAt,
  );
}

const Object _editorSentinel = Object();
