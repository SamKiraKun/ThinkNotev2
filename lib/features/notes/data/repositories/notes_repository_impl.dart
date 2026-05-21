import 'package:uuid/uuid.dart';

import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
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
  Future<NoteModel?> getNoteById(String id) async {
    final store = await loadStore();
    for (final note in store.notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  @override
  Future<NoteModel?> saveNote(NoteDraft draft) async {
    final store = await loadStore();
    final existingIndex = store.notes.indexWhere((note) => note.id == draft.id);
    final normalizedTags = _normalizeTags(draft.tags);
    final now = DateTime.now();

    if (existingIndex == -1 &&
        !_hasMeaningfulContent(draft.title, draft.content)) {
      return null;
    }

    final nextFolderId = draft.folderId ?? _fallbackFolderId(store.folders);

    if (existingIndex == -1) {
      final createdNote = NoteModel(
        id: draft.id ?? _uuid.v4(),
        title: draft.title.trim(),
        content: draft.content.trimRight(),
        folderId: nextFolderId,
        tags: normalizedTags,
        isPinned: draft.isPinned,
        isFavorite: draft.isFavorite,
        createdAt: now,
        updatedAt: now,
      );

      final updatedStore = store.copyWith(
        notes: <NoteModel>[createdNote, ...store.notes],
        tags: _mergeTags(store.tags, normalizedTags),
      );
      await _localDataSource.writeStore(updatedStore);
      return createdNote;
    }

    final current = store.notes[existingIndex];
    final updatedNote = current.copyWith(
      title: draft.title.trim(),
      content: draft.content.trimRight(),
      folderId: nextFolderId,
      tags: normalizedTags,
      isPinned: draft.isPinned,
      isFavorite: draft.isFavorite,
      updatedAt: now,
      isDeleted: false,
      deletedAt: null,
    );

    final updatedNotes = List<NoteModel>.from(store.notes)
      ..[existingIndex] = updatedNote;
    final updatedStore = store.copyWith(
      notes: updatedNotes,
      tags: _mergeTags(store.tags, normalizedTags),
    );
    await _localDataSource.writeStore(updatedStore);
    return updatedNote;
  }

  @override
  Future<void> moveToTrash(String id) async {
    await _mutateStore((store) {
      final now = DateTime.now();
      final updatedNotes = store.notes.map((note) {
        if (note.id != id) {
          return note;
        }
        return note.copyWith(
          isDeleted: true,
          deletedAt: now,
          updatedAt: now,
          isPinned: false,
        );
      }).toList(growable: false);
      return store.copyWith(notes: updatedNotes);
    });
  }

  @override
  Future<void> restoreNote(String id) async {
    await _mutateStore((store) {
      final now = DateTime.now();
      final updatedNotes = store.notes.map((note) {
        if (note.id != id) {
          return note;
        }
        return note.copyWith(
          isDeleted: false,
          deletedAt: null,
          updatedAt: now,
        );
      }).toList(growable: false);
      return store.copyWith(notes: updatedNotes);
    });
  }

  @override
  Future<void> deleteNote(String id) async {
    await _mutateStore((store) {
      final updatedNotes =
          store.notes.where((note) => note.id != id).toList(growable: false);
      return store.copyWith(notes: updatedNotes);
    });
  }

  @override
  Future<void> emptyTrash() async {
    await _mutateStore((store) {
      final updatedNotes =
          store.notes.where((note) => !note.isDeleted).toList(growable: false);
      return store.copyWith(notes: updatedNotes);
    });
  }

  @override
  Future<NoteModel> togglePin(String id) async {
    return _updateSingleNote(id, (note) {
      return note.copyWith(
        isPinned: !note.isPinned,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<NoteModel> toggleFavorite(String id) async {
    return _updateSingleNote(id, (note) {
      return note.copyWith(
        isFavorite: !note.isFavorite,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<FolderModel> createFolder(String name, {String emoji = '🗂️'}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    final store = await loadStore();
    final existing = _findFolderByName(store.folders, trimmedName);
    if (existing != null) {
      return existing;
    }

    final folder = FolderModel(
      id: _uuid.v4(),
      name: trimmedName,
      colorKey: _nextFolderColor(store.folders.length),
      emoji: emoji,
      createdAt: DateTime.now(),
    );

    final updatedStore = store.copyWith(
      folders: <FolderModel>[...store.folders, folder],
    );
    await _localDataSource.writeStore(updatedStore);
    return folder;
  }

  @override
  Future<FolderModel> renameFolder(String id, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    late FolderModel renamedFolder;
    await _mutateStore((store) {
      final updatedFolders = store.folders.map((folder) {
        if (folder.id != id) {
          return folder;
        }
        renamedFolder = folder.copyWith(name: trimmedName);
        return renamedFolder;
      }).toList(growable: false);
      return store.copyWith(folders: updatedFolders);
    });
    return renamedFolder;
  }

  @override
  Future<void> deleteFolder(String id) async {
    await _mutateStore((store) {
      final folder = store.folders.where((item) => item.id == id).firstOrNull;
      if (folder == null || folder.isSystem) {
        return store;
      }

      final fallbackFolderId = _fallbackFolderId(
          store.folders.where((item) => item.id != id).toList());
      final updatedFolders =
          store.folders.where((item) => item.id != id).toList(growable: false);
      final updatedNotes = store.notes.map((note) {
        if (note.folderId == id) {
          return note.copyWith(
              folderId: fallbackFolderId, updatedAt: DateTime.now());
        }
        return note;
      }).toList(growable: false);
      return store.copyWith(
        folders: updatedFolders,
        notes: updatedNotes,
      );
    });
  }

  @override
  Future<TagModel> createTag(String label, {String emoji = '#'}) async {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      throw ArgumentError('Tag label cannot be empty.');
    }

    final store = await loadStore();
    final existing = _findTagByLabel(store.tags, trimmedLabel);
    if (existing != null) {
      return existing;
    }

    final tag = TagModel(
      id: _uuid.v4(),
      label: trimmedLabel,
      createdAt: DateTime.now(),
      emoji: emoji,
    );

    final updatedStore = store.copyWith(
      tags: <TagModel>[...store.tags, tag],
    );
    await _localDataSource.writeStore(updatedStore);
    return tag;
  }

  @override
  Future<void> deleteTag(String id) async {
    await _mutateStore((store) {
      final tag = store.tags.where((item) => item.id == id).firstOrNull;
      if (tag == null) {
        return store;
      }

      final updatedTags =
          store.tags.where((item) => item.id != id).toList(growable: false);
      final updatedNotes = store.notes.map((note) {
        return note.copyWith(
          tags: note.tags
              .where((item) => item.toLowerCase() != tag.label.toLowerCase())
              .toList(growable: false),
          updatedAt: DateTime.now(),
        );
      }).toList(growable: false);
      return store.copyWith(tags: updatedTags, notes: updatedNotes);
    });
  }

  @override
  Future<void> saveRecentSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return;
    }

    await _mutateStore((store) {
      final entries = <String>[
        trimmedQuery,
        ...store.recentSearches.where(
          (entry) => entry.toLowerCase() != trimmedQuery.toLowerCase(),
        ),
      ];
      return store.copyWith(
        recentSearches: entries.take(8).toList(growable: false),
      );
    });
  }

  @override
  Future<void> clearRecentSearches() async {
    await _mutateStore((store) {
      return store.copyWith(recentSearches: const <String>[]);
    });
  }

  @override
  Future<AppPreferencesModel> updatePreferences(
      AppPreferencesModel preferences) async {
    await _mutateStore((store) {
      return store.copyWith(preferences: preferences);
    });
    return preferences;
  }

  @override
  Future<void> clearAllNotes() async {
    await _mutateStore((store) {
      return store.copyWith(notes: const <NoteModel>[]);
    });
  }

  Future<void> _mutateStore(
      NotesStoreModel Function(NotesStoreModel store) transform) async {
    final currentStore = await loadStore();
    final nextStore = transform(currentStore).withDefaults();
    await _localDataSource.writeStore(nextStore);
  }

  Future<NoteModel> _updateSingleNote(
    String id,
    NoteModel Function(NoteModel note) transform,
  ) async {
    final store = await loadStore();
    final index = store.notes.indexWhere((note) => note.id == id);
    if (index == -1) {
      throw StateError('Unable to find note $id.');
    }

    final updatedNote = transform(store.notes[index]);
    final updatedNotes = List<NoteModel>.from(store.notes)
      ..[index] = updatedNote;
    await _localDataSource.writeStore(store.copyWith(notes: updatedNotes));
    return updatedNote;
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

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
