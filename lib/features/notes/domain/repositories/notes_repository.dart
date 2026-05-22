import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../data/models/app_preferences_model.dart';
import '../../data/models/note_model.dart';
import '../../data/models/notes_store_model.dart';

class NoteDraft {
  const NoteDraft({
    this.id,
    required this.title,
    required this.content,
    this.folderId,
    this.tags = const <String>[],
    this.isPinned = false,
    this.isFavorite = false,
  });

  final String? id;
  final String title;
  final String content;
  final String? folderId;
  final List<String> tags;
  final bool isPinned;
  final bool isFavorite;
}

abstract class NotesRepository {
  Future<NotesStoreModel> loadStore();
  Future<NoteModel?> getNoteById(String id);
  Future<NoteModel?> saveNote(NoteDraft draft);
  Future<void> moveToTrash(String id);
  Future<void> restoreNote(String id);
  Future<NoteModel> archiveNote(String id);
  Future<NoteModel> unarchiveNote(String id);
  Future<void> deleteNote(String id);
  Future<void> emptyTrash();
  Future<NoteModel> togglePin(String id);
  Future<NoteModel> toggleFavorite(String id);
  Future<FolderModel> createFolder(
    String name, {
    String emoji = '🗂️',
  });
  Future<FolderModel> renameFolder(String id, String name);
  Future<void> deleteFolder(String id);
  Future<TagModel> createTag(
    String label, {
    String emoji = '#',
  });
  Future<void> deleteTag(String id);
  Future<void> saveRecentSearch(String query);
  Future<void> clearRecentSearches();
  Future<AppPreferencesModel> updatePreferences(
      AppPreferencesModel preferences);
  Future<void> replaceStore(NotesStoreModel store);
  Future<void> clearAllNotes();
}
