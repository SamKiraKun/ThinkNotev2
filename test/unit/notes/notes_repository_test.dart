import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinknote/core/database/app_database.dart';
import 'package:thinknote/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:thinknote/features/notes/data/models/app_preferences_model.dart';
import 'package:thinknote/features/notes/data/repositories/notes_repository_impl.dart';
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
        NotesLocalDataSource(preferences, database),
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
  });
}
