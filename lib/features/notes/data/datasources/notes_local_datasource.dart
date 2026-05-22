import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../domain/entities/note_entity.dart';
import '../models/app_preferences_model.dart';
import '../models/note_model.dart';
import '../models/notes_store_model.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    database.close();
  });
  return database;
});

final notesLocalDataSourceProvider = Provider<NotesLocalDataSource>((ref) {
  return NotesLocalDataSource(
    ref.watch(sharedPreferencesProvider),
    ref.watch(appDatabaseProvider),
  );
});

class NotesLocalDataSource {
  const NotesLocalDataSource(this._preferences, this._database);

  final SharedPreferences _preferences;
  final AppDatabase _database;

  Future<NotesStoreModel> readStore() async {
    await _migrateLegacyPreferencesIfNeeded();

    final database = await _database.instance;
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

    final store = NotesStoreModel(
      notes: notesRows.map(_noteFromRow).toList(growable: false),
      folders: folderRows.map(_folderFromRow).toList(growable: false),
      tags: tagRows.map(_tagFromRow).toList(growable: false),
      recentSearches:
          searchRows.map((row) => row['query'] as String).toList(growable: false),
      preferences: preferences,
    ).withDefaults();

    if (notesRows.isEmpty && folderRows.isEmpty && tagRows.isEmpty) {
      final emptyStore = NotesStoreModel.empty();
      await _writeStoreToDatabase(emptyStore);
      return emptyStore;
    }

    if (store.folders.length != folderRows.length ||
        store.tags.length != tagRows.length) {
      await _writeStoreToDatabase(store);
    }

    return store;
  }

  Future<void> writeStore(NotesStoreModel store) async {
    await _migrateLegacyPreferencesIfNeeded();
    await _writeStoreToDatabase(store.withDefaults());
  }

  Future<void> _migrateLegacyPreferencesIfNeeded() async {
    final hasMigrated =
        _preferences.getBool(StorageKeys.hasMigratedNotesStoreToDatabase) ??
            false;
    if (hasMigrated) {
      return;
    }

    final database = await _database.instance;
    final existingNotes = database.select('SELECT id FROM notes LIMIT 1');
    if (existingNotes.isNotEmpty) {
      await _preferences.setBool(
        StorageKeys.hasMigratedNotesStoreToDatabase,
        true,
      );
      return;
    }

    final rawStore = _preferences.getString(StorageKeys.notesStore);
    if (rawStore != null && rawStore.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStore);
        if (decoded is Map<String, dynamic>) {
          await _writeStoreToDatabase(NotesStoreModel.fromJson(decoded));
        }
      } catch (_) {
        await _writeStoreToDatabase(NotesStoreModel.empty());
      }
    }

    await _preferences.setBool(
      StorageKeys.hasMigratedNotesStoreToDatabase,
      true,
    );
  }

  Future<void> _writeStoreToDatabase(NotesStoreModel store) async {
    final database = await _database.instance;
    final normalizedStore = store.withDefaults();

    database.execute('BEGIN IMMEDIATE TRANSACTION');
    try {
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
            folder.name,
            folder.colorKey,
            folder.emoji,
            _boolToInt(folder.isSystem),
            folder.createdAt.toIso8601String(),
            folder.createdAt.toIso8601String(),
            'synced',
            null,
          ]);
        }

        for (final tag in normalizedStore.tags) {
          insertTag.execute([
            tag.id,
            null,
            tag.label,
            tag.emoji,
            tag.createdAt.toIso8601String(),
            tag.createdAt.toIso8601String(),
            'synced',
            null,
          ]);
        }

        for (final note in normalizedStore.notes) {
          insertNote.execute([
            note.id,
            note.remoteId,
            note.title,
            note.content,
            note.folderId,
            jsonEncode(note.tags),
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
          insertSearch.execute([index, normalizedStore.recentSearches[index]]);
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

      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
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

  NoteModel _noteFromRow(Row row) {
    return NoteModel(
      id: row['id'] as String,
      remoteId: row['remote_id'] as String?,
      title: row['title'] as String,
      content: row['content'] as String,
      folderId: row['folder_id'] as String?,
      tags: _decodeStringList(row['tags_json'] as String),
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

  FolderModel _folderFromRow(Row row) {
    return FolderModel(
      id: row['id'] as String,
      name: row['name'] as String,
      colorKey: row['color_key'] as String,
      emoji: row['emoji'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      isSystem: _intToBool(row['is_system'] as int),
    );
  }

  TagModel _tagFromRow(Row row) {
    return TagModel(
      id: row['id'] as String,
      label: row['label'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
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
}
