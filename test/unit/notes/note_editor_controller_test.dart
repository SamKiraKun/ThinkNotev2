import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinknote/bootstrap/dependency_injection.dart';
import 'package:thinknote/core/database/app_database.dart';
import 'package:thinknote/features/auth/auth_providers.dart';
import 'package:thinknote/features/folders/data/models/folder_model.dart';
import 'package:thinknote/features/folders/data/models/tag_model.dart';
import 'package:thinknote/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:thinknote/features/notes/data/models/app_preferences_model.dart';
import 'package:thinknote/features/notes/data/models/note_model.dart';
import 'package:thinknote/features/notes/data/models/notes_store_model.dart';
import 'package:thinknote/features/notes/domain/entities/note_entity.dart';
import 'package:thinknote/features/notes/domain/repositories/notes_repository.dart';
import 'package:thinknote/features/notes/presentation/controllers/note_editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteEditorController autosave', () {
    late AppDatabase database;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase.memory();
    });

    tearDown(() async {
      await database.close();
    });

    test('serializes overlapping new-note saves through one stable id',
        () async {
      final preferences = await SharedPreferences.getInstance();
      final localDataSource = NotesLocalDataSource(
        preferences,
        database,
        databaseName: ':memory:',
      );
      final repository = _SlowAutosaveRepository();
      final container = ProviderContainer(
        overrides: [
          currentAuthSessionProvider.overrideWithValue(null),
          notesLocalDataSourceProvider.overrideWithValue(localDataSource),
          notesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<NoteEditorState>(
        noteEditorControllerProvider(const NoteEditorArgs()),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = container.read(
        noteEditorControllerProvider(const NoteEditorArgs()).notifier,
      );
      await Future<void>.delayed(Duration.zero);

      controller.updateContent('First local draft');
      final firstSave = controller.saveNow();
      await Future<void>.delayed(Duration.zero);

      controller.updateContent('Second local draft');
      final secondSave = controller.saveNow();

      repository.releaseFirstSave();
      await Future.wait(<Future<void>>[firstSave, secondSave]);

      expect(repository.savedDrafts, hasLength(2));
      expect(
        repository.savedDrafts.map((draft) => draft.id).toSet(),
        hasLength(1),
      );
      expect(repository.savedNotes, hasLength(1));
      expect(repository.savedNotes.single.content, 'Second local draft');
      expect(controller.state.content, 'Second local draft');
      expect(controller.state.hasChanges, isFalse);
      expect(controller.state.noteId, repository.savedNotes.single.id);
    });

    test('opens with the provided local note snapshot before refresh finishes',
        () async {
      final preferences = await SharedPreferences.getInstance();
      final localDataSource = NotesLocalDataSource(
        preferences,
        database,
        databaseName: ':memory:',
      );
      final seededNote = NoteModel(
        id: 'note-1',
        title: 'Seeded note',
        content: 'Show this immediately.',
        folderId: 'work',
        createdAt: DateTime.parse('2025-02-01T08:00:00Z'),
        updatedAt: DateTime.parse('2025-02-01T08:00:00Z'),
      );
      final repository = _SlowAutosaveRepository()
        ..queueExistingNote(
          seededNote.copyWith(content: 'Refreshed local content.'),
        );
      final container = ProviderContainer(
        overrides: [
          currentAuthSessionProvider.overrideWithValue(null),
          notesLocalDataSourceProvider.overrideWithValue(localDataSource),
          notesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final args = NoteEditorArgs(
        noteId: seededNote.id,
        initialNote: seededNote,
      );
      final subscription = container.listen<NoteEditorState>(
        noteEditorControllerProvider(args),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = container.read(
        noteEditorControllerProvider(args).notifier,
      );

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.content, 'Show this immediately.');
      expect(controller.state.folderId, 'work');

      repository.releaseNoteLoad();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.content, 'Refreshed local content.');
      expect(controller.state.noteId, seededNote.id);
    });
  });
}

class _SlowAutosaveRepository implements NotesRepository {
  final List<NoteDraft> savedDrafts = <NoteDraft>[];
  final Map<String, NoteModel> _notesById = <String, NoteModel>{};
  final Completer<void> _firstSaveGate = Completer<void>();
  final Completer<void> _noteLoadGate = Completer<void>();

  List<NoteModel> get savedNotes => _notesById.values.toList(growable: false);

  void releaseFirstSave() {
    if (!_firstSaveGate.isCompleted) {
      _firstSaveGate.complete();
    }
  }

  void queueExistingNote(NoteModel note) {
    _notesById[note.id] = note;
  }

  void releaseNoteLoad() {
    if (!_noteLoadGate.isCompleted) {
      _noteLoadGate.complete();
    }
  }

  @override
  Future<NotesStoreModel> loadStore() async {
    return NotesStoreModel(
      notes: savedNotes,
      folders: const <FolderModel>[],
      tags: const <TagModel>[],
      recentSearches: const <String>[],
      preferences: const AppPreferencesModel(),
    ).withDefaults();
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    if (!_noteLoadGate.isCompleted) {
      await _noteLoadGate.future;
    }
    return _notesById[id];
  }

  @override
  Future<NoteModel?> saveNote(NoteDraft draft) async {
    savedDrafts.add(draft);
    if (savedDrafts.length == 1) {
      await _firstSaveGate.future;
    }

    if (draft.id == null ||
        (draft.title.trim().isEmpty && draft.content.trim().isEmpty)) {
      return null;
    }

    final existing = _notesById[draft.id];
    final now = DateTime.now();
    final note = NoteModel(
      id: draft.id!,
      title: draft.title.trim(),
      content: draft.content.trimRight(),
      folderId: draft.folderId ?? 'personal',
      tags: draft.tags,
      isPinned: draft.isPinned,
      isFavorite: draft.isFavorite,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      syncStatus: existing?.remoteId == null
          ? NoteSyncStatus.pendingCreate
          : NoteSyncStatus.pendingUpdate,
    );
    _notesById[note.id] = note;
    return note;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
