import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage.dart';
import '../models/notes_store_model.dart';

final notesLocalDataSourceProvider = Provider<NotesLocalDataSource>((ref) {
  return NotesLocalDataSource(ref.watch(sharedPreferencesProvider));
});

class NotesLocalDataSource {
  const NotesLocalDataSource(this._preferences);

  final SharedPreferences _preferences;

  Future<NotesStoreModel> readStore() async {
    final rawStore = _preferences.getString(StorageKeys.notesStore);
    if (rawStore == null || rawStore.isEmpty) {
      final emptyStore = NotesStoreModel.empty();
      await writeStore(emptyStore);
      return emptyStore;
    }

    final decoded = jsonDecode(rawStore);
    if (decoded is! Map<String, dynamic>) {
      final emptyStore = NotesStoreModel.empty();
      await writeStore(emptyStore);
      return emptyStore;
    }

    return NotesStoreModel.fromJson(decoded);
  }

  Future<void> writeStore(NotesStoreModel store) async {
    await _preferences.setString(
      StorageKeys.notesStore,
      jsonEncode(store.toJson()),
    );
  }
}
