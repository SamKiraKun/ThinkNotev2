import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/security/local_notes_cipher.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../auth/auth_providers.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../../sync/data/models/sync_delete_operation.dart';
import '../../domain/entities/note_entity.dart';
import '../models/app_preferences_model.dart';
import '../models/note_model.dart';
import '../models/notes_store_model.dart';

final notesDatabaseNameProvider = Provider<String>((ref) {
  final sessionUid = AppEnv.enableExperimentalSync
      ? ref.watch(currentAuthSessionProvider.select((session) => session?.uid))
      : null;
  return _databaseNameForCurrentSession(sessionUid);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});

final notesLocalDataSourceProvider = Provider<NotesLocalDataSource>((ref) {
  return NotesLocalDataSource(
    ref.watch(sharedPreferencesProvider),
    ref.watch(appDatabaseProvider),
    databaseName: ref.watch(notesDatabaseNameProvider),
    cipher: ref.watch(localNotesCipherProvider),
  );
});

class NotesLocalDataSource {
  NotesLocalDataSource(
    this._preferences,
    this._database, {
    required String databaseName,
    LocalNotesCipher? cipher,
  })  : _databaseName = databaseName,
        _cipher = cipher ?? const PassthroughLocalNotesCipher();

  final SharedPreferences _preferences;
  final AppDatabase _database;
  final String _databaseName;
  final LocalNotesCipher _cipher;

  Future<NotesStoreModel> readStore() async {
    await _migrateLegacyPreferencesIfNeeded();

    final snapshot = await _runSerialized((database) async {
      final notesRows = database.select(
        'SELECT * FROM notes ORDER BY updated_at DESC',
      );
      final folderRows = database.select(
        'SELECT * FROM folders ORDER BY created_at ASC',
      );
      final tagRows = database.select(
        'SELECT * FROM tags ORDER BY created_at ASC',
      );
      final searchRows = database.select(
        'SELECT * FROM recent_searches ORDER BY position ASC',
      );
      final preferences = _readPreferences(database);
      final shouldRewriteEncryptedFields = _rowsRequireEncryption(
        notesRows: notesRows,
        folderRows: folderRows,
        tagRows: tagRows,
        searchRows: searchRows,
      );

      final store = NotesStoreModel(
        notes: await _readNotes(notesRows),
        folders: await _readFolders(folderRows),
        tags: await _readTags(tagRows),
        recentSearches: await _readRecentSearches(searchRows),
        preferences: preferences,
      ).withDefaults();

      if (notesRows.isEmpty && folderRows.isEmpty && tagRows.isEmpty) {
        return _ReadStoreSnapshot(
          store: NotesStoreModel.empty(),
          shouldRewriteStore: true,
        );
      }

      return _ReadStoreSnapshot(
        store: store,
        shouldRewriteStore: store.folders.length != folderRows.length ||
            store.tags.length != tagRows.length ||
            shouldRewriteEncryptedFields,
      );
    });

    if (snapshot.shouldRewriteStore) {
      await writeStore(snapshot.store);
    }

    return snapshot.store;
  }

  Future<void> writeStore(NotesStoreModel store) async {
    await _migrateLegacyPreferencesIfNeeded();
    await _runWriteTransaction(
      (database) => _writeStoreToDatabase(database, store.withDefaults()),
      debugLabel: 'write notes store',
    );
  }

  Future<String?> readSyncState(String key) async {
    return _runSerialized((database) async {
      final rows = database.select(
        'SELECT value FROM sync_state WHERE key = ? LIMIT 1',
        [key],
      );
      if (rows.isEmpty) {
        return null;
      }

      return rows.first['value'] as String;
    });
  }

  Future<void> writeSyncState(String key, String value) async {
    await _runSerialized((database) async {
      _writeSyncStateToDatabase(database, key, value);
    });
  }

  Future<void> deleteSyncState(String key) async {
    await _runSerialized((database) async {
      _deleteSyncStateFromDatabase(database, key);
    });
  }

  Future<void> upsertDeleteOperation(SyncDeleteOperation operation) async {
    await _runSerialized((database) async {
      _upsertDeleteOperationToDatabase(database, operation);
    });
  }

  Future<List<SyncDeleteOperation>> readPendingDeleteOperations() async {
    return _runSerialized((database) async {
      final rows = database.select(
        '''
          SELECT *
          FROM sync_queue
          WHERE operation = 'delete'
          ORDER BY created_at ASC
        ''',
      );
      return rows.map(SyncDeleteOperation.fromRow).toList(growable: false);
    });
  }

  Future<void> clearPendingDeleteOperations(List<String> queueIds) async {
    if (queueIds.isEmpty) {
      return;
    }

    await _runSerialized((database) async {
      _clearPendingDeleteOperationsFromDatabase(database, queueIds);
    });
  }

  Future<void> markDeleteOperationsFailed(
    List<String> queueIds,
    String errorMessage,
  ) async {
    if (queueIds.isEmpty) {
      return;
    }

    await _runSerialized((database) async {
      _markDeleteOperationsFailedInDatabase(database, queueIds, errorMessage);
    });
  }

  Future<void> commitSyncResult({
    required NotesStoreModel store,
    required List<String> queueIdsToClear,
    required Map<String, String> syncStateUpdates,
    List<String> syncStateDeletes = const <String>[],
  }) async {
    await _runWriteTransaction(
      (database) async {
        await _writeStoreToDatabase(database, store.withDefaults());
        _clearPendingDeleteOperationsFromDatabase(database, queueIdsToClear);
        for (final entry in syncStateUpdates.entries) {
          _writeSyncStateToDatabase(database, entry.key, entry.value);
        }
        for (final key in syncStateDeletes) {
          _deleteSyncStateFromDatabase(database, key);
        }
      },
      debugLabel: 'commit sync result',
    );
  }

  Future<void> recordSyncFailure({
    required List<String> queueIds,
    required String errorMessage,
    required Map<String, String> syncStateUpdates,
  }) async {
    await _runWriteTransaction(
      (database) async {
        _markDeleteOperationsFailedInDatabase(database, queueIds, errorMessage);
        for (final entry in syncStateUpdates.entries) {
          _writeSyncStateToDatabase(database, entry.key, entry.value);
        }
      },
      debugLabel: 'record sync failure',
    );
  }

  Future<void> _migrateLegacyPreferencesIfNeeded() async {
    final hasMigrated =
        _preferences.getBool(StorageKeys.hasMigratedNotesStoreToDatabase) ??
            false;
    if (hasMigrated) {
      return;
    }

    final rawStore = _preferences.getString(StorageKeys.notesStore);
    await _runWriteTransaction(
      (database) async {
        final existingNotes = database.select('SELECT id FROM notes LIMIT 1');
        if (existingNotes.isNotEmpty) {
          return;
        }

        if (rawStore == null || rawStore.isEmpty) {
          return;
        }

        try {
          final decoded = jsonDecode(rawStore);
          if (decoded is Map<String, dynamic>) {
            await _writeStoreToDatabase(
              database,
              NotesStoreModel.fromJson(decoded),
            );
            return;
          }
        } catch (_) {
          // Fall back to a clean store when the legacy payload is unreadable.
        }

        await _writeStoreToDatabase(database, NotesStoreModel.empty());
      },
      debugLabel: 'migrate legacy notes store',
    );

    await _preferences.setBool(
      StorageKeys.hasMigratedNotesStoreToDatabase,
      true,
    );
  }

  Future<void> _writeStoreToDatabase(
    Database database,
    NotesStoreModel store,
  ) async {
    final normalizedStore = store.withDefaults();

    database.execute('DELETE FROM note_tags');
    database.execute('DELETE FROM notes');
    database.execute('DELETE FROM folders');
    database.execute('DELETE FROM tags');
    database.execute('DELETE FROM recent_searches');
    database.execute('DELETE FROM app_preferences');

    final insertFolder = database.prepare('''
        INSERT OR REPLACE INTO folders (
          id, remote_id, name, color_key, emoji, is_system, created_at,
          updated_at, sync_status, last_synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
    final insertTag = database.prepare('''
        INSERT OR REPLACE INTO tags (
          id, remote_id, label, emoji, created_at, updated_at, sync_status,
          last_synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');
    final insertNote = database.prepare('''
        INSERT OR REPLACE INTO notes (
          id, remote_id, title, content, folder_id, tags_json, is_pinned,
          is_favorite, is_archived, is_deleted, created_at, updated_at,
          deleted_at, sync_status, last_synced_at, server_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
    final insertSearch = database.prepare('''
        INSERT OR REPLACE INTO recent_searches (position, query) VALUES (?, ?)
      ''');
    final insertPreference = database.prepare('''
        INSERT OR REPLACE INTO app_preferences (key, value) VALUES (?, ?)
      ''');
    final insertNoteTag = database.prepare('''
        INSERT OR REPLACE INTO note_tags (note_id, tag_id) VALUES (?, ?)
      ''');

    try {
      for (final folder in normalizedStore.folders) {
        insertFolder.execute([
          folder.id,
          null,
          await _cipher.encrypt(folder.name),
          folder.colorKey,
          folder.emoji,
          _boolToInt(folder.isSystem),
          folder.createdAt.toIso8601String(),
          folder.updatedAt.toIso8601String(),
          'synced',
          null,
        ]);
      }

      for (final tag in normalizedStore.tags) {
        insertTag.execute([
          tag.id,
          null,
          await _cipher.encrypt(tag.label),
          tag.emoji,
          tag.createdAt.toIso8601String(),
          tag.updatedAt.toIso8601String(),
          'synced',
          null,
        ]);
      }

      for (final note in normalizedStore.notes) {
        insertNote.execute([
          note.id,
          note.remoteId,
          await _cipher.encrypt(note.title),
          await _cipher.encrypt(note.content),
          note.folderId,
          await _cipher.encrypt(jsonEncode(note.tags)),
          _boolToInt(note.isPinned),
          _boolToInt(note.isFavorite),
          _boolToInt(note.isArchived),
          _boolToInt(note.isDeleted),
          note.createdAt.toIso8601String(),
          note.updatedAt.toIso8601String(),
          note.deletedAt?.toIso8601String(),
          note.syncStatus.storageValue,
          note.lastSyncedAt?.toIso8601String(),
          note.serverVersion,
        ]);
      }

      for (var index = 0;
          index < normalizedStore.recentSearches.length;
          index += 1) {
        insertSearch.execute([
          index,
          await _cipher.encrypt(normalizedStore.recentSearches[index]),
        ]);
      }

      for (final entry in _preferencesToMap(normalizedStore.preferences).entries) {
        insertPreference.execute([entry.key, entry.value]);
      }

      final tagsByLabel = <String, TagModel>{
        for (final tag in normalizedStore.tags) tag.label.toLowerCase(): tag,
      };
      for (final note in normalizedStore.notes) {
        for (final label in note.tags) {
          final tag = tagsByLabel[label.toLowerCase()];
          if (tag != null) {
            insertNoteTag.execute([note.id, tag.id]);
          }
        }
      }
    } finally {
      insertFolder.close();
      insertTag.close();
      insertNote.close();
      insertSearch.close();
      insertPreference.close();
      insertNoteTag.close();
    }
  }

  Future<T> _runSerialized<T>(Future<T> Function(Database database) operation) {
    return _database.serialize(
      operation,
      databaseName: _databaseName,
    );
  }

  Future<T> _runWriteTransaction<T>(
    Future<T> Function(Database database) operation, {
    required String debugLabel,
  }) {
    return _database.runInTransaction(
      operation,
      databaseName: _databaseName,
      debugLabel: debugLabel,
    );
  }

  void _writeSyncStateToDatabase(Database database, String key, String value) {
    database.execute(
      '''
        INSERT OR REPLACE INTO sync_state (key, value, updated_at)
        VALUES (?, ?, ?)
      ''',
      [key, value, DateTime.now().toIso8601String()],
    );
  }

  void _deleteSyncStateFromDatabase(Database database, String key) {
    database.execute(
      'DELETE FROM sync_state WHERE key = ?',
      [key],
    );
  }

  void _upsertDeleteOperationToDatabase(
    Database database,
    SyncDeleteOperation operation,
  ) {
    database.execute(
      '''
        INSERT OR REPLACE INTO sync_queue (
          id, entity_type, entity_id, operation, payload_json, created_at,
          retry_count, last_error
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        operation.id,
        operation.entityType.storageValue,
        operation.entityId,
        'delete',
        operation.payloadJsonString,
        operation.createdAt.toIso8601String(),
        operation.retryCount,
        operation.lastError,
      ],
    );
  }

  void _clearPendingDeleteOperationsFromDatabase(
    Database database,
    List<String> queueIds,
  ) {
    if (queueIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(queueIds.length, '?').join(', ');
    database.execute(
      'DELETE FROM sync_queue WHERE id IN ($placeholders)',
      queueIds,
    );
  }

  void _markDeleteOperationsFailedInDatabase(
    Database database,
    List<String> queueIds,
    String errorMessage,
  ) {
    if (queueIds.isEmpty) {
      return;
    }

    final placeholders = List.filled(queueIds.length, '?').join(', ');
    database.execute(
      '''
        UPDATE sync_queue
        SET retry_count = retry_count + 1,
            last_error = ?
        WHERE id IN ($placeholders)
      ''',
      <Object?>[
        errorMessage,
        ...queueIds,
      ],
    );
  }

  AppPreferencesModel _readPreferences(Database database) {
    final rows = database.select('SELECT * FROM app_preferences');
    final values = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    final previewLines = int.tryParse(values['preview_lines'] ?? '');
    return AppPreferencesModel.fromJson(
      <String, dynamic>{
        'default_sort_order': values['default_sort_order'],
        'preview_lines': previewLines,
        'theme_preference': values['theme_preference'],
      },
    );
  }

  Future<List<NoteModel>> _readNotes(ResultSet rows) async {
    final items = <NoteModel>[];
    for (final row in rows) {
      items.add(await _noteFromRow(row));
    }
    return items;
  }

  Future<List<FolderModel>> _readFolders(ResultSet rows) async {
    final items = <FolderModel>[];
    for (final row in rows) {
      items.add(await _folderFromRow(row));
    }
    return items;
  }

  Future<List<TagModel>> _readTags(ResultSet rows) async {
    final items = <TagModel>[];
    for (final row in rows) {
      items.add(await _tagFromRow(row));
    }
    return items;
  }

  Future<List<String>> _readRecentSearches(ResultSet rows) async {
    final items = <String>[];
    for (final row in rows) {
      items.add(await _cipher.decrypt(row['query'] as String));
    }
    return items;
  }

  Future<NoteModel> _noteFromRow(Row row) async {
    return NoteModel(
      id: row['id'] as String,
      remoteId: row['remote_id'] as String?,
      title: await _cipher.decrypt(row['title'] as String),
      content: await _cipher.decrypt(row['content'] as String),
      folderId: row['folder_id'] as String?,
      tags:
          _decodeStringList(await _cipher.decrypt(row['tags_json'] as String)),
      isPinned: _intToBool(row['is_pinned'] as int),
      isFavorite: _intToBool(row['is_favorite'] as int),
      isArchived: _intToBool(row['is_archived'] as int),
      isDeleted: _intToBool(row['is_deleted'] as int),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: _parseNullableDate(row['deleted_at'] as String?),
      syncStatus: NoteSyncStatusX.fromStorage(row['sync_status'] as String?),
      lastSyncedAt: _parseNullableDate(row['last_synced_at'] as String?),
      serverVersion: row['server_version'] as int,
    );
  }

  Future<FolderModel> _folderFromRow(Row row) async {
    return FolderModel(
      id: row['id'] as String,
      name: await _cipher.decrypt(row['name'] as String),
      colorKey: row['color_key'] as String,
      emoji: row['emoji'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isSystem: _intToBool(row['is_system'] as int),
    );
  }

  Future<TagModel> _tagFromRow(Row row) async {
    return TagModel(
      id: row['id'] as String,
      label: await _cipher.decrypt(row['label'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      emoji: row['emoji'] as String,
    );
  }

  Map<String, String> _preferencesToMap(AppPreferencesModel preferences) {
    return <String, String>{
      'default_sort_order': preferences.defaultSortOrder.storageValue,
      'preview_lines': preferences.previewLines.toString(),
      'theme_preference': preferences.themePreference.storageValue,
    };
  }

  List<String> _decodeStringList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.map((entry) => entry.toString()).toList(growable: false);
      }
    } catch (_) {
      return const <String>[];
    }
    return const <String>[];
  }

  DateTime? _parseNullableDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }

  int _boolToInt(bool value) => value ? 1 : 0;

  bool _intToBool(int value) => value == 1;

  bool _rowsRequireEncryption({
    required ResultSet notesRows,
    required ResultSet folderRows,
    required ResultSet tagRows,
    required ResultSet searchRows,
  }) {
    bool containsPlaintext(
      ResultSet rows,
      List<String> keys,
    ) {
      for (final row in rows) {
        for (final key in keys) {
          final value = row[key];
          if (value is String &&
              value.isNotEmpty &&
              !_cipher.isEncrypted(value)) {
            return true;
          }
        }
      }
      return false;
    }

    return containsPlaintext(notesRows, ['title', 'content', 'tags_json']) ||
        containsPlaintext(folderRows, ['name']) ||
        containsPlaintext(tagRows, ['label']) ||
        containsPlaintext(searchRows, ['query']);
  }
}

class _ReadStoreSnapshot {
  const _ReadStoreSnapshot({
    required this.store,
    required this.shouldRewriteStore,
  });

  final NotesStoreModel store;
  final bool shouldRewriteStore;
}

String _databaseNameForCurrentSession(String? uid) {
  if (uid == null || uid.trim().isEmpty) {
    return 'thinknote.sqlite';
  }

  final normalizedUid = uid.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
  return 'thinknote_$normalizedUid.sqlite';
}
