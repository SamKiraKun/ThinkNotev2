import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/dependency_injection.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../data/models/app_preferences_model.dart';
import '../../data/models/notes_store_model.dart';
import 'notes_state.dart';

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, NotesState>(NotesController.new);

class NotesController extends AsyncNotifier<NotesState> {
  @override
  Future<NotesState> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }

  Future<void> moveToTrash(String id) async {
    await ref.read(notesRepositoryProvider).moveToTrash(id);
    ref.invalidateSelf();
  }

  Future<void> restore(String id) async {
    await ref.read(notesRepositoryProvider).restoreNote(id);
    ref.invalidateSelf();
  }

  Future<void> archive(String id) async {
    await ref.read(notesRepositoryProvider).archiveNote(id);
    ref.invalidateSelf();
  }

  Future<void> unarchive(String id) async {
    await ref.read(notesRepositoryProvider).unarchiveNote(id);
    ref.invalidateSelf();
  }

  Future<void> deletePermanently(String id) async {
    await ref.read(notesRepositoryProvider).deleteNote(id);
    ref.invalidateSelf();
  }

  Future<void> emptyTrash() async {
    await ref.read(notesRepositoryProvider).emptyTrash();
    ref.invalidateSelf();
  }

  Future<void> togglePin(String id) async {
    await ref.read(notesRepositoryProvider).togglePin(id);
    ref.invalidateSelf();
  }

  Future<void> toggleFavorite(String id) async {
    await ref.read(notesRepositoryProvider).toggleFavorite(id);
    ref.invalidateSelf();
  }

  Future<void> createFolder(String name, {String emoji = '🗂️'}) async {
    await ref.read(notesRepositoryProvider).createFolder(name, emoji: emoji);
    ref.invalidateSelf();
  }

  Future<void> renameFolder(String id, String name) async {
    await ref.read(notesRepositoryProvider).renameFolder(id, name);
    ref.invalidateSelf();
  }

  Future<void> deleteFolder(String id) async {
    await ref.read(notesRepositoryProvider).deleteFolder(id);
    ref.invalidateSelf();
  }

  Future<void> createTag(String label, {String emoji = '#'}) async {
    await ref.read(notesRepositoryProvider).createTag(label, emoji: emoji);
    ref.invalidateSelf();
  }

  Future<void> deleteTag(String id) async {
    await ref.read(notesRepositoryProvider).deleteTag(id);
    ref.invalidateSelf();
  }

  Future<void> saveRecentSearch(String query) async {
    await ref.read(notesRepositoryProvider).saveRecentSearch(query);
    ref.invalidateSelf();
  }

  Future<void> clearRecentSearches() async {
    await ref.read(notesRepositoryProvider).clearRecentSearches();
    ref.invalidateSelf();
  }

  Future<void> updatePreferences(AppPreferencesModel preferences) async {
    await ref.read(notesRepositoryProvider).updatePreferences(preferences);
    ref.invalidateSelf();
  }

  Future<void> replaceStore(NotesStoreModel store) async {
    await ref.read(notesRepositoryProvider).replaceStore(store);
    ref.invalidateSelf();
  }

  Future<void> clearAllNotes() async {
    await ref.read(notesRepositoryProvider).clearAllNotes();
    ref.invalidateSelf();
  }

  Future<NotesState> _load() async {
    final store = await ref.read(notesRepositoryProvider).loadStore();
    return NotesState(
      notes: store.notes,
      folders: store.folders,
      tags: store.tags,
      recentSearches: store.recentSearches,
      preferences: store.preferences,
    );
  }
}

final availableFoldersProvider = Provider<List<FolderModel>>((ref) {
  final notesState = ref.watch(notesControllerProvider).valueOrNull;
  return notesState?.folders ?? const <FolderModel>[];
});

final availableTagsProvider = Provider<List<TagModel>>((ref) {
  final notesState = ref.watch(notesControllerProvider).valueOrNull;
  return notesState?.tags ?? const <TagModel>[];
});
