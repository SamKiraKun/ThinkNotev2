import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinknote/core/database/app_database.dart';
import 'package:thinknote/core/network/authenticated_api_client.dart';
import 'package:thinknote/features/auth/auth_providers.dart';
import 'package:thinknote/features/auth/domain/entities/auth_session.dart';
import 'package:thinknote/features/auth/domain/repositories/auth_repository.dart';
import 'package:thinknote/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:thinknote/features/notes/data/models/note_model.dart';
import 'package:thinknote/features/notes/data/models/notes_store_model.dart';
import 'package:thinknote/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:thinknote/features/notes/domain/entities/note_entity.dart';
import 'package:thinknote/features/notes/domain/repositories/notes_repository.dart';
import 'package:thinknote/features/sync/presentation/controllers/sync_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncController', () {
    late AppDatabase database;
    late NotesLocalDataSource localDataSource;
    late NotesRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      database = AppDatabase.memory();
      localDataSource = NotesLocalDataSource(
        preferences,
        database,
        databaseName: ':memory:',
      );
      repository = NotesRepositoryImpl(localDataSource);
    });

    tearDown(() async {
      await database.close();
    });

    test('preserves newer local edits made while sync is in flight', () async {
      final created = await repository.saveNote(
        const NoteDraft(
          title: 'Launch plan',
          content: 'Initial draft',
          folderId: 'personal',
        ),
      );

      expect(created, isNotNull);

      final originalNote = created!;
      final authRepository = _FakeAuthRepository();
      final apiClient = AuthenticatedApiClient(
        MockClient((request) async {
          if (request.url.path == '/health') {
            return _healthResponse();
          }

          if (request.url.path == '/sync/push') {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            final pushedNotes = payload['notes'] as List<dynamic>;
            expect(pushedNotes, hasLength(1));
            expect(
              (pushedNotes.single as Map<String, dynamic>)['content'],
              'Initial draft',
            );

            return _jsonResponse(
              <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'server_time': '2025-02-01T09:00:00Z',
                },
              },
            );
          }

          if (request.url.path == '/sync/pull') {
            await repository.saveNote(
              NoteDraft(
                id: originalNote.id,
                title: originalNote.title,
                content: 'Newer local edit',
                folderId: originalNote.folderId,
                tags: originalNote.tags,
                isPinned: originalNote.isPinned,
                isFavorite: originalNote.isFavorite,
              ),
            );

            return _jsonResponse(
              <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'server_time': '2025-02-01T09:00:05Z',
                  'notes': const <Map<String, dynamic>>[],
                  'folders': const <Map<String, dynamic>>[],
                  'tags': const <Map<String, dynamic>>[],
                  'deleted_notes': const <Map<String, dynamic>>[],
                  'deleted_folders': const <Map<String, dynamic>>[],
                  'deleted_tags': const <Map<String, dynamic>>[],
                },
              },
            );
          }

          throw StateError('Unexpected request to ${request.url}');
        }),
        authRepository,
      );

      final container = ProviderContainer(
        overrides: [
          currentAuthSessionProvider.overrideWithValue(
            const AuthSession(uid: 'user-1'),
          ),
          notesLocalDataSourceProvider.overrideWithValue(localDataSource),
          authenticatedApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncControllerProvider.notifier).syncNow();

      final store = await repository.loadStore();
      final note = store.notes.single;

      expect(note.content, 'Newer local edit');
      expect(note.syncStatus, isNot(NoteSyncStatus.synced));
    });

    test('marks pushed notes synced even when incremental pull is empty',
        () async {
      final store = NotesStoreModel.empty().copyWith(
        notes: <NoteModel>[
          NoteModel(
            id: 'note-1',
            title: 'Offline draft',
            content: 'Created while the device clock was behind.',
            folderId: 'personal',
            createdAt: DateTime.parse('2025-02-01T08:00:00Z'),
            updatedAt: DateTime.parse('2025-02-01T08:00:00Z'),
            syncStatus: NoteSyncStatus.pendingCreate,
          ),
        ],
      );
      await localDataSource.writeStore(store);
      await localDataSource.writeSyncState(
        'last_server_sync_at',
        '2025-02-01T09:00:00Z',
      );

      final authRepository = _FakeAuthRepository();
      final apiClient = AuthenticatedApiClient(
        MockClient((request) async {
          if (request.url.path == '/health') {
            return _healthResponse();
          }

          if (request.url.path == '/sync/push') {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            final pushedNotes = payload['notes'] as List<dynamic>;
            expect(pushedNotes, hasLength(1));
            expect(
              (pushedNotes.single as Map<String, dynamic>)['id'],
              'note-1',
            );

            return _jsonResponse(
              <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'server_time': '2025-02-01T09:05:00Z',
                },
              },
            );
          }

          if (request.url.path == '/sync/pull') {
            expect(
                request.url.queryParameters['since'], '2025-02-01T09:00:00Z');

            return _jsonResponse(
              <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'server_time': '2025-02-01T09:05:05Z',
                  'notes': const <Map<String, dynamic>>[],
                  'folders': const <Map<String, dynamic>>[],
                  'tags': const <Map<String, dynamic>>[],
                  'deleted_notes': const <Map<String, dynamic>>[],
                  'deleted_folders': const <Map<String, dynamic>>[],
                  'deleted_tags': const <Map<String, dynamic>>[],
                },
              },
            );
          }

          throw StateError('Unexpected request to ${request.url}');
        }),
        authRepository,
      );

      final container = ProviderContainer(
        overrides: [
          currentAuthSessionProvider.overrideWithValue(
            const AuthSession(uid: 'user-1'),
          ),
          notesLocalDataSourceProvider.overrideWithValue(localDataSource),
          authenticatedApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncControllerProvider.notifier).syncNow();

      final syncedStore = await localDataSource.readStore();
      final note = syncedStore.notes.single;

      expect(note.syncStatus, NoteSyncStatus.synced);
      expect(note.lastSyncedAt, DateTime.parse('2025-02-01T09:05:05Z'));
      expect(
        DateTime.parse(
          (await localDataSource.readSyncState('last_server_sync_at'))!,
        ),
        DateTime.parse('2025-02-01T09:05:05Z'),
      );
      expect(await localDataSource.readSyncState('sync_retry_after'), isNull);
      expect(
        await localDataSource.readSyncState('sync_failure_count'),
        isNull,
      );
    });

    test('preserves the default local folder contract across sync', () async {
      final store = NotesStoreModel.empty().copyWith(
        notes: <NoteModel>[
          NoteModel(
            id: 'note-default-folder',
            title: 'Personal note',
            content: 'Stored under the local default folder.',
            folderId: 'personal',
            createdAt: DateTime.parse('2025-02-01T10:00:00Z'),
            updatedAt: DateTime.parse('2025-02-01T10:00:00Z'),
            syncStatus: NoteSyncStatus.pendingCreate,
          ),
        ],
      );
      await localDataSource.writeStore(store);

      final authRepository = _FakeAuthRepository();
      final apiClient = AuthenticatedApiClient(
        MockClient((request) async {
          if (request.url.path == '/health') {
            return _healthResponse();
          }

          if (request.url.path == '/sync/push') {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            final pushedNotes = payload['notes'] as List<dynamic>;
            final pushedNote = pushedNotes.single as Map<String, dynamic>;

            expect(pushedNote['folder_id'], isNull);

            return _jsonResponse(
              <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'server_time': '2025-02-01T10:05:00Z',
                },
              },
            );
          }

          if (request.url.path == '/sync/pull') {
            return _jsonResponse(
              <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'server_time': '2025-02-01T10:05:05Z',
                  'notes': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'note-default-folder',
                      'title': 'Personal note',
                      'content': 'Stored under the local default folder.',
                      'folder_id': null,
                      'tags': const <String>[],
                      'is_pinned': false,
                      'is_favorite': false,
                      'is_archived': false,
                      'is_deleted': false,
                      'created_at': '2025-02-01T10:00:00Z',
                      'updated_at': '2025-02-01T10:00:00Z',
                    },
                  ],
                  'folders': const <Map<String, dynamic>>[],
                  'tags': const <Map<String, dynamic>>[],
                  'deleted_notes': const <Map<String, dynamic>>[],
                  'deleted_folders': const <Map<String, dynamic>>[],
                  'deleted_tags': const <Map<String, dynamic>>[],
                },
              },
            );
          }

          throw StateError('Unexpected request to ${request.url}');
        }),
        authRepository,
      );

      final container = ProviderContainer(
        overrides: [
          currentAuthSessionProvider.overrideWithValue(
            const AuthSession(uid: 'user-1'),
          ),
          notesLocalDataSourceProvider.overrideWithValue(localDataSource),
          authenticatedApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncControllerProvider.notifier).syncNow();

      final syncedStore = await localDataSource.readStore();
      final note = syncedStore.notes.single;

      expect(note.folderId, 'personal');
      expect(note.syncStatus, NoteSyncStatus.synced);
      expect(note.lastSyncedAt, DateTime.parse('2025-02-01T10:05:05Z'));
    });

    test('keeps pending deletes queued when pull fails after a successful push',
        () async {
      final created = await repository.saveNote(
        const NoteDraft(
          title: 'Queued delete',
          content: 'Keep this tombstone queued until sync fully succeeds.',
          folderId: 'personal',
        ),
      );

      expect(created, isNotNull);
      await repository.deleteNote(created!.id);

      final authRepository = _FakeAuthRepository();
      final apiClient = AuthenticatedApiClient(
        MockClient((request) async {
          if (request.url.path == '/health') {
            return _healthResponse();
          }

          if (request.url.path == '/sync/push') {
            return _jsonResponse(
              <String, dynamic>{
                'success': true,
                'data': <String, dynamic>{
                  'server_time': '2025-02-01T09:10:00Z',
                },
              },
            );
          }

          if (request.url.path == '/sync/pull') {
            return http.Response(
              jsonEncode(
                <String, dynamic>{
                  'message': 'Backend unavailable for pull.',
                },
              ),
              503,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }

          throw StateError('Unexpected request to ${request.url}');
        }),
        authRepository,
      );

      final container = ProviderContainer(
        overrides: [
          currentAuthSessionProvider.overrideWithValue(
            const AuthSession(uid: 'user-1'),
          ),
          notesLocalDataSourceProvider.overrideWithValue(localDataSource),
          authenticatedApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncControllerProvider.notifier).syncNow();

      final pendingDeletes =
          await localDataSource.readPendingDeleteOperations();
      expect(pendingDeletes, hasLength(1));
      expect(pendingDeletes.single.entityId, created.id);
      expect(pendingDeletes.single.retryCount, 1);
      expect(
        container.read(syncControllerProvider).lastErrorType,
        SyncErrorType.api,
      );
    });
  });
}

http.Response _healthResponse() {
  return http.Response(
    jsonEncode(
      <String, dynamic>{
        'status': 'ok',
        'message': 'Backend is running!',
      },
    ),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthSession?> authStateChanges() => const Stream<AuthSession?>.empty();

  @override
  AuthSession? currentSession() => const AuthSession(uid: 'user-1');

  @override
  Future<String> currentIdToken({bool forceRefresh = false}) async {
    return 'test-token';
  }

  @override
  Future<AuthSession> reloadSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendEmailVerification() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
