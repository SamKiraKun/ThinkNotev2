import 'package:flutter_test/flutter_test.dart';
import 'package:thinknote/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reopens a closed in-memory database when it is requested again',
      () async {
    final database = AppDatabase.memory();

    final firstConnection = await database.instance;
    firstConnection.execute(
      "INSERT OR REPLACE INTO sync_state (key, value, updated_at) VALUES ('k', 'v', '2026-06-01T00:00:00Z')",
    );

    await database.close();

    final reopenedConnection = await database.instance;
    expect(reopenedConnection, isNot(same(firstConnection)));

    final rows = reopenedConnection.select(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      ['table', 'sync_state'],
    );
    expect(rows, hasLength(1));

    await database.close();
  });
}