import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinknote/core/database/app_database.dart';
import 'package:thinknote/core/security/local_notes_cipher.dart';
import 'package:thinknote/features/notes/data/datasources/notes_local_datasource.dart';
import 'package:thinknote/features/notes/data/models/note_model.dart';
import 'package:thinknote/features/notes/data/models/notes_store_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notes local data source encrypts stored note content and decrypts it on read',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.memory();
    final cipher = SecureLocalNotesCipher(
      MemorySecretStore(),
      keyNamespace: 'unit-test',
    );
    final dataSource = NotesLocalDataSource(
      preferences,
      database,
      databaseName: ':memory:',
      cipher: cipher,
    );

    final now = DateTime.utc(2026, 5, 24, 12);
    final store = NotesStoreModel.empty().copyWith(
      notes: <NoteModel>[
        NoteModel(
          id: 'note-1',
          title: 'Encrypted title',
          content: 'Sensitive body text',
          tags: const <String>['Private'],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await dataSource.writeStore(store);

    final db = await database.instance;
    final rows = db.select('SELECT title, content, tags_json FROM notes');
    expect(rows, hasLength(1));
    expect(rows.single['title'], isA<String>());
    expect(rows.single['title'] as String, startsWith('enc:v1:'));
    expect(rows.single['title'] as String, isNot('Encrypted title'));
    expect(rows.single['content'] as String, startsWith('enc:v1:'));
    expect(rows.single['tags_json'] as String, startsWith('enc:v1:'));

    final restored = await dataSource.readStore();
    expect(restored.notes.single.title, 'Encrypted title');
    expect(restored.notes.single.content, 'Sensitive body text');
    expect(restored.notes.single.tags, ['Private']);

    await database.close();
  });
}
