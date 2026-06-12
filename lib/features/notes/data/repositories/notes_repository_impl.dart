import 'package:uuid/uuid.dart';

import '../../../sync/data/models/sync_delete_operation.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../domain/entities/note_entity.dart';
import '../../domain/repositories/notes_repository.dart';
import '../datasources/notes_local_datasource.dart';
import '../models/app_preferences_model.dart';
import '../models/note_model.dart';
import '../models/notes_store_model.dart';

class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._localDataSource);

  final NotesLocalDataSource _localDataSource;
  final Uuid _uuid = const Uuid();

  @override
  Future<NotesStoreModel> loadStore() {
    return _localDataSource.readStore();
  }

  @override
  Future<NoteModel?> getNoteById(String id) {
    return _localDataSource.readNoteById(id);
  }

  @override
  Future<NoteModel?> saveNote(NoteDraft draft) async {
    final noteId = draft.id ?? _uuid.v4();
    final saveContext = await _localDataSource.readNoteSaveContext(noteId);
    final existing = saveContext.note;
    final normalizedTags = _normalizeTags(draft.tags);
    final now = DateTime.now();

    if (existing == null &&
        !_hasMeaningfulContent(draft.title, draft.content)) {
      return null;
    }

    if (existing == null) {
      final nextFolderId =
          draft.folderId ?? _fallbackFolderId(saveContext.folders);
      final createdNote = NoteModel(
        id: noteId,
        title: draft.title.trim(),
        content: draft.content.trimRight(),
        folderId: nextFolderId,
        tags: normalizedTags,
        isPinned: draft.isPinned,
        isFavorite: draft.isFavorite,
        createdAt: now,
        updatedAt: now,
        syncStatus: NoteSyncStatus.pendingCreate,
      );

      await _localDataSource.upsertNoteWithTags(
        note: createdNote,
        tags: _mergeTags(saveContext.tags, normalizedTags),
      );
      return createdNote;
    }

    final nextFolderId = draft.folderId ??
        existing.folderId ??
        _fallbackFolderId(saveContext.folders);
    final updatedNote = existing.copyWith(
      title: draft.title.trim(),
      content: draft.content.trimRight(),
      folderId: nextFolderId,
      tags: normalizedTags,
      isPinned: draft.isPinned,
      isFavorite: draft.isFavorite,
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
      syncStatus: _pendingMutationStatus(existing),
    );

    await _localDataSource.upsertNoteWithTags(
      note: updatedNote,
      tags: _mergeTags(saveContext.tags, normalizedTags),
    );
    return updatedNote;
  }

  @override
  Future<void> moveToTrash(String id) async {
    await _updateSingleNote(id, (note) {
      final now = DateTime.now();
      return note.copyWith(
        isDeleted: true,
        deletedAt: now,
        updatedAt: now,
        isPinned: false,
        isArchived: false,
        syncStatus: _pendingMutationStatus(note),
      );
    });
  }

  @override
  Future<void> restoreNote(String id) async {
    await _updateSingleNote(id, (note) {
      return note.copyWith(
        isDeleted: false,
        deletedAt: null,
        updatedAt: DateTime.now(),
        syncStatus: _pendingMutationStatus(note),
      );
    });
  }

  @override
  Future<NoteModel> archiveNote(String id) async {
    return _updateSingleNote(id, (note) {
      return note.copyWith(
        isArchived: true,
        isDeleted: false,
        deletedAt: null,
        isPinned: false,
        updatedAt: DateTime.now(),
        syncStatus: _pendingMutationStatus(note),
      );
    });
  }

  @override
  Future<NoteModel> unarchiveNote(String id) async {
    return _updateSingleNote(id, (note) {
      return note.copyWith(
        isArchived: false,
        updatedAt: DateTime.now(),
        syncStatus: _pendingMutationStatus(note),
      );
    });
  }

  @override
  Future<void> deleteNote(String id) async {
    final note = await _localDataSource.readNoteById(id);
    if (note == null) {
      return;
    }

    await _localDataSource.deleteNotesPermanently(
      noteIds: <String>[note.id],
      operations: <SyncDeleteOperation>[
        SyncDeleteOperation.forEntity(
          entityType: SyncEntityType.note,
          entityId: note.id,
          deletedAt: DateTime.now().toUtc(),
        ),
      ],
    );
  }

  @override
  Future<void> emptyTrash() async {
    final deletedNoteIds =
        await _localDataSource.readNoteIds(deletedOnly: true);
    if (deletedNoteIds.isEmpty) {
      return;
    }

    await _localDataSource.deleteNotesPermanently(
      noteIds: deletedNoteIds,
      operations: deletedNoteIds.map((noteId) {
        return SyncDeleteOperation.forEntity(
          entityType: SyncEntityType.note,
          entityId: noteId,
          deletedAt: DateTime.now().toUtc(),
        );
      }).toList(growable: false),
    );
  }

  @override
  Future<NoteModel> togglePin(String id) async {
    return _updateSingleNote(id, (note) {
      return note.copyWith(
        isPinned: !note.isPinned,
        updatedAt: DateTime.now(),
        syncStatus: _pendingMutationStatus(note),
      );
    });
  }

  @override
  Future<NoteModel> toggleFavorite(String id) async {
    return _updateSingleNote(id, (note) {
      return note.copyWith(
        isFavorite: !note.isFavorite,
        updatedAt: DateTime.now(),
        syncStatus: _pendingMutationStatus(note),
      );
    });
  }

  @override
  Future<FolderModel> createFolder(String name, {String emoji = ''}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    final folders = await _localDataSource.readFolders();
    final existing = _findFolderByName(folders, trimmedName);
    if (existing != null) {
      return existing;
    }

    final folder = FolderModel(
      id: _uuid.v4(),
      name: trimmedName,
      colorKey: _nextFolderColor(folders.length),
      emoji: emoji,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _localDataSource.upsertFolder(folder);
    return folder;
  }

  @override
  Future<FolderModel> renameFolder(String id, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    final existing = await _localDataSource.readFolderById(id);
    if (existing == null) {
      throw StateError('Unable to find folder $id.');
    }

    final renamedFolder = existing.copyWith(
      name: trimmedName,
      updatedAt: DateTime.now(),
    );
    await _localDataSource.upsertFolder(renamedFolder);
    return renamedFolder;
  }

  @override
  Future<void> deleteFolder(String id) async {
    final folder = await _localDataSource.readFolderById(id);
    if (folder == null || folder.isSystem) {
      return;
    }

    final folders = await _localDataSource.readFolders();
    final fallbackFolderId = _fallbackFolderId(
      folders.where((item) => item.id != id).toList(growable: false),
    );
    final updatedAt = DateTime.now();
    final affectedNotes = await _localDataSource.readNotesByFolderId(id);
    final updatedNotes = affectedNotes.map((note) {
      if (note.folderId == id) {
        return note.copyWith(
          folderId: fallbackFolderId,
          updatedAt: updatedAt,
          syncStatus: _pendingMutationStatus(note),
        );
      }
      return note;
    }).toList(growable: false);
    await _localDataSource.deleteFolderAndReassignNotes(
      folderId: id,
      operation: SyncDeleteOperation.forEntity(
        entityType: SyncEntityType.folder,
        entityId: folder.id,
        deletedAt: DateTime.now().toUtc(),
      ),
      reassignedNotes: updatedNotes,
    );
  }

  @override
  Future<TagModel> createTag(String label, {String emoji = '#'}) async {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      throw ArgumentError('Tag label cannot be empty.');
    }

    final tags = await _localDataSource.readTags();
    final existing = _findTagByLabel(tags, trimmedLabel);
    if (existing != null) {
      return existing;
    }

    final tag = TagModel(
      id: _uuid.v4(),
      label: trimmedLabel,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      emoji: emoji,
    );

    await _localDataSource.upsertTag(tag);
    return tag;
  }

  @override
  Future<void> deleteTag(String id) async {
    final tag = await _localDataSource.readTagById(id);
    if (tag == null) {
      return;
    }

    final updatedAt = DateTime.now();
    final remainingTags = (await _localDataSource.readTags())
        .where((item) => item.id != id)
        .toList(growable: false);
    final taggedNotes = await _localDataSource.readNotesByTagId(id);
    final updatedNotes = taggedNotes.map((note) {
      return note.copyWith(
        tags: note.tags
            .where((item) => item.toLowerCase() != tag.label.toLowerCase())
            .toList(growable: false),
        updatedAt: updatedAt,
        syncStatus: _pendingMutationStatus(note),
      );
    }).toList(growable: false);
    await _localDataSource.deleteTagAndUpdateNotes(
      tagId: id,
      operation: SyncDeleteOperation.forEntity(
        entityType: SyncEntityType.tag,
        entityId: tag.id,
        deletedAt: DateTime.now().toUtc(),
      ),
      updatedNotes: updatedNotes,
      remainingTags: remainingTags,
    );
  }

  @override
  Future<void> saveRecentSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return;
    }

    final currentEntries = await _localDataSource.readRecentSearches();
    final entries = <String>[
      trimmedQuery,
      ...currentEntries.where(
        (entry) => entry.toLowerCase() != trimmedQuery.toLowerCase(),
      ),
    ];
    await _localDataSource.writeRecentSearches(
      entries.take(8).toList(growable: false),
    );
  }

  @override
  Future<void> clearRecentSearches() async {
    await _localDataSource.writeRecentSearches(const <String>[]);
  }

  @override
  Future<AppPreferencesModel> updatePreferences(
      AppPreferencesModel preferences) async {
    await _localDataSource.writePreferencesModel(preferences);
    return preferences;
  }

  @override
  Future<void> replaceStore(NotesStoreModel store) async {
    await _localDataSource.writeStore(store.withDefaults());
  }

  @override
  Future<void> clearAllNotes() async {
    final noteIds = await _localDataSource.readNoteIds();
    if (noteIds.isEmpty) {
      return;
    }

    await _localDataSource.deleteNotesPermanently(
      noteIds: noteIds,
      operations: noteIds.map((noteId) {
        return SyncDeleteOperation.forEntity(
          entityType: SyncEntityType.note,
          entityId: noteId,
          deletedAt: DateTime.now().toUtc(),
        );
      }).toList(growable: false),
    );
  }

  Future<NoteModel> _updateSingleNote(
    String id,
    NoteModel Function(NoteModel note) transform,
  ) async {
    final existing = await _localDataSource.readNoteById(id);
    if (existing == null) {
      throw StateError('Unable to find note $id.');
    }

    final updatedNote = transform(existing);
    await _localDataSource.upsertNote(updatedNote);
    return updatedNote;
  }

  NoteSyncStatus _pendingMutationStatus(NoteModel note) {
    return note.remoteId == null
        ? NoteSyncStatus.pendingCreate
        : NoteSyncStatus.pendingUpdate;
  }

  List<String> _normalizeTags(List<String> tags) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawTag in tags) {
      final trimmed = rawTag.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  List<TagModel> _mergeTags(
      List<TagModel> existingTags, List<String> noteTags) {
    final updatedTags = List<TagModel>.from(existingTags);
    for (final tag in noteTags) {
      final exists = updatedTags
          .any((item) => item.label.toLowerCase() == tag.toLowerCase());
      if (!exists) {
        updatedTags.add(
          TagModel(
            id: _uuid.v4(),
            label: tag,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            emoji: '#',
          ),
        );
      }
    }
    return updatedTags;
  }

  bool _hasMeaningfulContent(String title, String content) {
    return title.trim().isNotEmpty || content.trim().isNotEmpty;
  }

  String _fallbackFolderId(List<FolderModel> folders) {
    if (folders.isEmpty) {
      return 'personal';
    }
    return folders.first.id;
  }

  FolderModel? _findFolderByName(List<FolderModel> folders, String name) {
    for (final folder in folders) {
      if (folder.name.toLowerCase() == name.toLowerCase()) {
        return folder;
      }
    }
    return null;
  }

  TagModel? _findTagByLabel(List<TagModel> tags, String label) {
    for (final tag in tags) {
      if (tag.label.toLowerCase() == label.toLowerCase()) {
        return tag;
      }
    }
    return null;
  }

  String _nextFolderColor(int index) {
    const keys = <String>['personal', 'study', 'ideas', 'work', 'journal'];
    return keys[index % keys.length];
  }
}
