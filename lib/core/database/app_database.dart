import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  AppDatabase({Database? database})
      : _databaseFuture = database == null
            ? _openOnDeviceDatabase()
            : Future<Database>.value(database);

  AppDatabase.memory() : this(database: sqlite3.openInMemory());

  final Future<Database> _databaseFuture;
  bool _schemaReady = false;

  Future<Database> get instance async {
    final database = await _databaseFuture;
    if (!_schemaReady) {
      _createSchema(database);
      _schemaReady = true;
    }
    return database;
  }

  Future<void> close() async {
    final database = await _databaseFuture;
    database.close();
  }

  static Future<Database> _openOnDeviceDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, 'thinknote.sqlite');
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
