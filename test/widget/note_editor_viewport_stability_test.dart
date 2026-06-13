import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinknote/bootstrap/dependency_injection.dart';
import 'package:thinknote/core/database/app_database.dart';
import 'package:thinknote/core/theme/app_theme.dart';
import 'package:thinknote/features/auth/auth_providers.dart';
import 'package:thinknote/features/folders/data/models/folder_model.dart';
import 'package:thinknote/features/folders/data/models/tag_model.dart';
import 'package:thinknote/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:thinknote/features/notes/data/models/app_preferences_model.dart';
import 'package:thinknote/features/notes/data/models/note_model.dart';
import 'package:thinknote/features/notes/data/models/notes_store_model.dart';
import 'package:thinknote/features/notes/domain/entities/note_entity.dart';
import 'package:thinknote/features/notes/domain/repositories/notes_repository.dart';
import 'package:thinknote/features/notes/presentation/controllers/notes_controller.dart';
import 'package:thinknote/features/notes/presentation/controllers/notes_state.dart';
import 'package:thinknote/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:thinknote/features/sync/presentation/controllers/sync_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'editor viewport stays anchored through keyboard, save, and sync updates',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final database = AppDatabase.memory();
      addTearDown(database.close);

      final localDataSource = NotesLocalDataSource(
        preferences,
        database,
        databaseName: ':memory:',
      );
      final repository = _ImmediateNotesRepository();
      late _FakeSyncController fakeSyncController;

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthSessionProvider.overrideWithValue(null),
            notesLocalDataSourceProvider.overrideWithValue(localDataSource),
            notesRepositoryProvider.overrideWithValue(repository),
            notesControllerProvider.overrideWith(
              () => _FakeNotesController(_notesState()),
            ),
            syncControllerProvider.overrideWith((ref) {
              fakeSyncController = _FakeSyncController(ref);
              return fakeSyncController;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const NoteEditorScreen(
              initialFolderId: 'personal',
            ),
          ),
        ),
      );

      await tester.pump();

      final appBarFinder = find.byKey(const ValueKey('note-editor-app-bar'));
      final metadataFinder =
          find.byKey(const ValueKey('note-editor-metadata-card'));
      final mainCardFinder =
          find.byKey(const ValueKey('note-editor-main-card'));
      final bodyFieldFinder =
          find.byKey(const ValueKey('note-editor-body-field'));
      final headerStatusFinder =
          find.byKey(const ValueKey('note-editor-header-status'));

      expect(appBarFinder, findsOneWidget);
      expect(metadataFinder, findsOneWidget);
      expect(mainCardFinder, findsOneWidget);
      expect(bodyFieldFinder, findsOneWidget);
      expect(headerStatusFinder, findsOneWidget);

      await tester.tap(bodyFieldFinder);
      await tester.pump();

      final appBarTopBefore = tester.getTopLeft(appBarFinder).dy;
      final metadataTopBefore = tester.getTopLeft(metadataFinder).dy;
      final mainCardTopBefore = tester.getTopLeft(mainCardFinder).dy;
      final bodyTopBefore = tester.getTopLeft(bodyFieldFinder).dy;
      final headerStatusWidthBefore = tester.getSize(headerStatusFinder).width;

      final initialBodyField = tester.widget<TextField>(bodyFieldFinder);
      final initialController = initialBodyField.controller;
      final initialFocusNode = initialBodyField.focusNode;

      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();

      expect(tester.getTopLeft(appBarFinder).dy, appBarTopBefore);
      expect(tester.getTopLeft(metadataFinder).dy, metadataTopBefore);
      expect(tester.getTopLeft(mainCardFinder).dy, mainCardTopBefore);
      expect(tester.getTopLeft(bodyFieldFinder).dy, bodyTopBefore);

      final keyboardBodyField = tester.widget<TextField>(bodyFieldFinder);
      expect(
          identical(keyboardBodyField.controller, initialController), isTrue);
      expect(identical(keyboardBodyField.focusNode, initialFocusNode), isTrue);

      await tester.enterText(
          bodyFieldFinder, 'A stable editor should not jump.');
      await tester.pump();

      expect(
        tester.widget<TextField>(bodyFieldFinder).focusNode?.hasFocus ?? false,
        isTrue,
      );
      expect(tester.getSize(headerStatusFinder).width, headerStatusWidthBefore);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(tester.getTopLeft(appBarFinder).dy, appBarTopBefore);
      expect(tester.getTopLeft(metadataFinder).dy, metadataTopBefore);
      expect(tester.getTopLeft(mainCardFinder).dy, mainCardTopBefore);
      expect(tester.getTopLeft(bodyFieldFinder).dy, bodyTopBefore);
      expect(tester.getSize(headerStatusFinder).width, headerStatusWidthBefore);

      fakeSyncController.beginSync();
      await tester.pump();

      expect(find.text('Syncing...'), findsWidgets);
      expect(tester.getTopLeft(appBarFinder).dy, appBarTopBefore);
      expect(tester.getTopLeft(metadataFinder).dy, metadataTopBefore);
      expect(tester.getTopLeft(mainCardFinder).dy, mainCardTopBefore);
      expect(tester.getTopLeft(bodyFieldFinder).dy, bodyTopBefore);
      expect(tester.getSize(headerStatusFinder).width, headerStatusWidthBefore);

      fakeSyncController.finishSync();
      await tester.pump();

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();

      final finalBodyField = tester.widget<TextField>(bodyFieldFinder);
      expect(identical(finalBodyField.controller, initialController), isTrue);
      expect(identical(finalBodyField.focusNode, initialFocusNode), isTrue);
      expect(tester.getTopLeft(appBarFinder).dy, appBarTopBefore);
      expect(tester.getTopLeft(metadataFinder).dy, metadataTopBefore);
      expect(tester.getTopLeft(mainCardFinder).dy, mainCardTopBefore);
      expect(tester.getTopLeft(bodyFieldFinder).dy, bodyTopBefore);
      expect(find.text('A stable editor should not jump.'), findsOneWidget);
    },
  );
}

NotesState _notesState() {
  final folder = FolderModel(
    id: 'personal',
    name: 'Personal',
    colorKey: 'personal',
    emoji: '',
    createdAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
    updatedAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
  );

  return NotesState(
    notes: const <NoteModel>[],
    folders: <FolderModel>[folder],
    tags: const <TagModel>[],
    recentSearches: const <String>[],
    preferences: const AppPreferencesModel(),
  );
}

class _FakeNotesController extends NotesController {
  _FakeNotesController(this.notesState);

  final NotesState notesState;

  @override
  Future<NotesState> build() async => notesState;
}

class _FakeSyncController extends SyncController {
  _FakeSyncController(super.ref);

  @override
  Future<void> scheduleSync({
    bool forceFullPull = false,
    bool rethrowOnError = false,
  }) async {}

  @override
  Future<void> syncNow({
    bool forceFullPull = false,
    bool rethrowOnError = false,
  }) async {}

  void beginSync() {
    state = state.copyWith(
      isSyncing: true,
      lastError: null,
      lastErrorType: null,
    );
  }

  void finishSync() {
    state = state.copyWith(
      isSyncing: false,
      lastSyncedAt: DateTime.parse('2026-06-13T08:00:00.000Z'),
      lastError: null,
      lastErrorType: null,
    );
  }
}

class _ImmediateNotesRepository implements NotesRepository {
  final Map<String, NoteModel> _notesById = <String, NoteModel>{};

  @override
  Future<NotesStoreModel> loadStore() async {
    return NotesStoreModel(
      notes: _notesById.values.toList(growable: false),
      folders: const <FolderModel>[],
      tags: const <TagModel>[],
      recentSearches: const <String>[],
      preferences: const AppPreferencesModel(),
    );
  }

  @override
  Future<NoteModel?> getNoteById(String id) async => _notesById[id];

  @override
  Future<NoteModel?> saveNote(NoteDraft draft) async {
    if (draft.id == null ||
        (draft.title.trim().isEmpty && draft.content.trim().isEmpty)) {
      return null;
    }

    final now = DateTime.parse('2026-06-13T08:00:00.000Z');
    final existing = _notesById[draft.id];
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
      syncStatus: existing == null
          ? NoteSyncStatus.pendingCreate
          : NoteSyncStatus.pendingUpdate,
    );
    _notesById[note.id] = note;
    return note;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
