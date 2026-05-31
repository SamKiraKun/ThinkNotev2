import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  AppDatabase({
    Database? database,
    String databaseName = 'thinknote.sqlite',
  })  : _defaultDatabaseName = databaseName,
        _database = database,
        _activeDatabaseName = database == null ? null : databaseName;

  AppDatabase.memory()
      : _defaultDatabaseName = _memoryDatabaseName,
        _database = sqlite3.openInMemory(),
        _activeDatabaseName = _memoryDatabaseName;

  static const String _memoryDatabaseName = ':memory:';

  final String _defaultDatabaseName;
  Database? _database;
  String? _activeDatabaseName;
  bool _schemaReady = false;
  Future<Database>? _openingDatabase;
  String? _openingDatabaseName;
  Future<void> _serializedOperations = Future<void>.value();

  Future<Database> get instance => getDatabase();

  Future<Database> getDatabase({String? databaseName}) async {
    final resolvedDatabaseName = databaseName ?? _defaultDatabaseName;

    while (true) {
      final database = _database;
      if (database != null &&
          _activeDatabaseName == resolvedDatabaseName &&
          _isUsable(database)) {
        debugPrint(
          '[AppDatabase] Reusing open database $resolvedDatabaseName.',
        );
        await _ensureSchema(database);
        return database;
      }

      final openingDatabase = _openingDatabase;
      if (openingDatabase != null) {
        if (_openingDatabaseName == resolvedDatabaseName) {
          return openingDatabase;
        }

        try {
          await openingDatabase;
        } catch (_) {
          // Retry the open path after the in-flight attempt finishes.
        }
        continue;
      }

      final completer = Completer<Database>();
      _openingDatabase = completer.future;
      _openingDatabaseName = resolvedDatabaseName;

      try {
        final reopened = await _reopenDatabase(resolvedDatabaseName);
        completer.complete(reopened);
        return reopened;
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
        rethrow;
      } finally {
        _openingDatabase = null;
        _openingDatabaseName = null;
      }
    }
  }

  Future<T> serialize<T>(
    FutureOr<T> Function(Database database) operation, {
    String? databaseName,
  }) {
    final completer = Completer<T>();
    _serializedOperations = _serializedOperations.catchError((_) {}).then((_) async {
      try {
        final database = await getDatabase(databaseName: databaseName);
        completer.complete(await operation(database));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<T> runInTransaction<T>(
    Future<T> Function(Database database) operation, {
    String? databaseName,
    String debugLabel = 'database write',
  }) {
    final resolvedDatabaseName = databaseName ?? _defaultDatabaseName;
    return serialize(
      (database) async {
        debugPrint(
          '[AppDatabase] BEGIN IMMEDIATE TRANSACTION for $debugLabel on $resolvedDatabaseName.',
        );
        database.execute('BEGIN IMMEDIATE TRANSACTION');

        try {
          final result = await operation(database);
          database.execute('COMMIT');
          debugPrint(
            '[AppDatabase] COMMIT for $debugLabel on $resolvedDatabaseName.',
          );
          return result;
        } catch (error, stackTrace) {
          debugPrint(
            '[AppDatabase] ROLLBACK for $debugLabel on $resolvedDatabaseName after ${error.runtimeType}: $error',
          );
          try {
            database.execute('ROLLBACK');
          } catch (rollbackError, rollbackStackTrace) {
            debugPrint(
              '[AppDatabase] ROLLBACK failed on $resolvedDatabaseName after ${rollbackError.runtimeType}: $rollbackError',
            );
            debugPrintStack(stackTrace: rollbackStackTrace);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
      databaseName: resolvedDatabaseName,
    );
  }

  Future<void> close() async {
    try {
      await _serializedOperations;
    } catch (_) {
      // A failed operation should not block test cleanup or deliberate shutdown.
    }

    final database = _database;
    final activeDatabaseName = _activeDatabaseName ?? _defaultDatabaseName;
    _database = null;
    _activeDatabaseName = null;
    _schemaReady = false;

    if (database == null) {
      debugPrint('[AppDatabase] Close requested with no active database.');
      return;
    }

    debugPrint('[AppDatabase] Closing database $activeDatabaseName.');
    try {
      if (_isUsable(database)) {
        database.close();
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[AppDatabase] Close failed on $activeDatabaseName after ${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _ensureSchema(Database database) async {
    if (_schemaReady) {
      return;
    }

    _createSchema(database);
    _schemaReady = true;
  }

  Future<Database> _reopenDatabase(String databaseName) async {
    final previousDatabase = _database;
    final previousDatabaseName = _activeDatabaseName;

    if (previousDatabase != null) {
      if (_isUsable(previousDatabase)) {
        debugPrint(
          '[AppDatabase] Closing database ${previousDatabaseName ?? _defaultDatabaseName} before opening $databaseName.',
        );
        previousDatabase.close();
      } else {
        debugPrint(
          '[AppDatabase] Reopening database $databaseName after detecting a stale closed handle.',
        );
      }
    } else {
      debugPrint('[AppDatabase] Opening database $databaseName.');
    }

    final database = await _openOnDeviceDatabase(databaseName);
    _database = database;
    _activeDatabaseName = databaseName;
    _schemaReady = false;
    await _ensureSchema(database);
    return database;
  }

  bool _isUsable(Database database) {
    try {
      database.select('SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Database> _openOnDeviceDatabase(String databaseName) async {
    if (databaseName == _memoryDatabaseName) {
      return sqlite3.openInMemory();
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, databaseName);
    return sqlite3.open(filePath);
  }

  static void _createSchema(Database database) {
    database.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        remote_id TEXT,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        folder_id TEXT,
        tags_json TEXT NOT NULL DEFAULT '[]',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        last_synced_at TEXT,
        server_version INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS folders (
        id TEXT PRIMARY KEY,
        remote_id TEXT,
        name TEXT NOT NULL,
        color_key TEXT NOT NULL DEFAULT 'personal',
        emoji TEXT NOT NULL DEFAULT '',
        is_system INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        last_synced_at TEXT
      );

      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        remote_id TEXT,
        label TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        last_synced_at TEXT
      );

      CREATE TABLE IF NOT EXISTS note_tags (
        note_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (note_id, tag_id)
      );

      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      );

      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS recent_searches (
        position INTEGER PRIMARY KEY,
        query TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS notes_updated_idx ON notes(updated_at);
      CREATE INDEX IF NOT EXISTS notes_deleted_idx ON notes(is_deleted);
      CREATE INDEX IF NOT EXISTS notes_archived_idx ON notes(is_archived);
      CREATE INDEX IF NOT EXISTS sync_queue_created_idx ON sync_queue(created_at);
    ''');
  }
}
