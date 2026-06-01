import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinknote/core/database/app_database.dart';
import 'package:thinknote/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:thinknote/features/notes/data/models/app_preferences_model.dart';
import 'package:thinknote/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:thinknote/features/notes/domain/entities/note_entity.dart';
import 'package:thinknote/features/notes/domain/repositories/notes_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotesRepositoryImpl', () {
    late NotesRepository repository;
    late AppDatabase database;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      database = AppDatabase.memory();
      repository = NotesRepositoryImpl(
        NotesLocalDataSource(
          preferences,
          database,
          databaseName: ':memory:',
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('creates and persists a meaningful note', () async {
      final created = await repository.saveNote(
        const NoteDraft(
          title: 'Dream life plan',
          content: 'Build something small every day.',
          folderId: 'personal',
          tags: <String>['Goals'],
        ),
      );

      final store = await repository.loadStore();

      expect(created, isNotNull);
      expect(store.notes, hasLength(1));
      expect(store.notes.first.displayTitle, 'Dream life plan');
      expect(store.notes.first.tags, contains('Goals'));
    });

    test('upserts autosave drafts with a stable note id', () async {
      final created = await repository.saveNote(
        const NoteDraft(
          id: 'draft-note-1',
          title: 'First autosave',
          content: 'Initial local content.',
          folderId: 'personal',
        ),
      );
      final updated = await repository.saveNote(
        const NoteDraft(
          id: 'draft-note-1',
          title: 'First autosave',
          content: 'Latest local content.',
          folderId: 'personal',
        ),
      );

      final store = await repository.loadStore();

      expect(created?.id, 'draft-note-1');
      expect(updated?.id, 'draft-note-1');
      expect(store.notes, hasLength(1));
      expect(store.notes.single.id, 'draft-note-1');
      expect(store.notes.single.content, 'Latest local content.');
      expect(store.notes.single.syncStatus, NoteSyncStatus.pendingCreate);
    });

    test('preserves an existing folder when an update omits folderId',
        () async {
      final created = await repository.saveNote(
        const NoteDraft(
          id: 'folder-preserve-note',
          title: 'Work draft',
          content: 'Keep this in Work.',
          folderId: 'work',
        ),
      );

      final updated = await repository.saveNote(
        const NoteDraft(
          id: 'folder-preserve-note',
          title: 'Work draft',
          content: 'Still in Work after the update.',
        ),
      );

      expect(created?.folderId, 'work');
      expect(updated?.folderId, 'work');
    });

    test('moves notes to trash, restores them, and deletes permanently',
        () async {
      final created = await repository.saveNote(
        const NoteDraft(
          title: 'Temporary',
          content: 'This note will be deleted.',
        ),
      );

      expect(created, isNotNull);

      await repository.moveToTrash(created!.id);
      var store = await repository.loadStore();
      expect(store.notes.single.isDeleted, isTrue);

      await repository.restoreNote(created.id);
      store = await repository.loadStore();
      expect(store.notes.single.isDeleted, isFalse);

      await repository.deleteNote(created.id);
      store = await repository.loadStore();
      expect(store.notes, isEmpty);

      final db = await database.instance;
      final queueRows = db.select(
        'SELECT entity_type, entity_id, operation FROM sync_queue',
      );
      expect(queueRows, hasLength(1));
      expect(queueRows.single['entity_type'], 'note');
      expect(queueRows.single['entity_id'], created.id);
      expect(queueRows.single['operation'], 'delete');
    });

    test('archives and unarchives notes separately from trash', () async {
      final created = await repository.saveNote(
        const NoteDraft(
          title: 'Reference',
          content: 'Keep this out of the active list.',
        ),
      );

      expect(created, isNotNull);

      await repository.archiveNote(created!.id);
      var store = await repository.loadStore();
      expect(store.notes.single.isArchived, isTrue);
      expect(store.notes.single.isDeleted, isFalse);

      await repository.unarchiveNote(created.id);
      store = await repository.loadStore();
      expect(store.notes.single.isArchived, isFalse);

      await repository.archiveNote(created.id);
      await repository.moveToTrash(created.id);
      store = await repository.loadStore();
      expect(store.notes.single.isArchived, isFalse);
      expect(store.notes.single.isDeleted, isTrue);
    });

    test('updates stored preferences', () async {
      const preferences = AppPreferencesModel(
        defaultSortOrder: NoteSortOrder.titleAsc,
        previewLines: 3,
        themePreference: AppThemePreference.dark,
      );

      await repository.updatePreferences(preferences);
      final store = await repository.loadStore();

      expect(store.preferences.defaultSortOrder, NoteSortOrder.titleAsc);
      expect(store.preferences.previewLines, 3);
      expect(store.preferences.themePreference, AppThemePreference.dark);
    });

    test('deletes custom folders with a queued tombstone and reassigns notes',
        () async {
      final folder = await repository.createFolder('Launch board', emoji: 'W');
      final created = await repository.saveNote(
        NoteDraft(
          title: 'Sprint notes',
          content: 'Move this note when the folder is deleted.',
          folderId: folder.id,
        ),
      );

      await repository.deleteFolder(folder.id);
      final store = await repository.loadStore();

      expect(store.folders.any((item) => item.id == folder.id), isFalse);
      expect(store.notes.single.id, created!.id);
      expect(store.notes.single.folderId, isNot(folder.id));

      final db = await database.instance;
      final queueRows = db.select(
        "SELECT entity_type, entity_id FROM sync_queue WHERE entity_type = 'folder'",
      );
      expect(queueRows, hasLength(1));
      expect(queueRows.single['entity_id'], folder.id);
    });

    test('deletes custom tags with a queued tombstone and strips note labels',
        () async {
      final tag = await repository.createTag('Launch', emoji: '#');
      await repository.saveNote(
        const NoteDraft(
          title: 'Checklist',
          content: 'Remove launch tag everywhere.',
          tags: <String>['Launch'],
        ),
      );

      await repository.deleteTag(tag.id);
      final store = await repository.loadStore();

      expect(store.tags.any((item) => item.id == tag.id), isFalse);
      expect(store.notes.single.tags, isNot(contains('Launch')));

      final db = await database.instance;
      final queueRows = db.select(
        "SELECT entity_type, entity_id FROM sync_queue WHERE entity_type = 'tag'",
      );
      expect(queueRows, hasLength(1));
      expect(queueRows.single['entity_id'], tag.id);
    });
  });
}
