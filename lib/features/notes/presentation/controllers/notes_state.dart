import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../data/models/app_preferences_model.dart';
import '../../data/models/note_model.dart';
import '../../data/models/notes_store_model.dart';

class FolderSummary {
  const FolderSummary({
    required this.folder,
    required this.noteCount,
  });

  final FolderModel folder;
  final int noteCount;
}

class TagSummary {
  const TagSummary({
    required this.tag,
    required this.noteCount,
  });

  final TagModel tag;
  final int noteCount;
}

class NotesState {
  const NotesState({
    required this.notes,
    required this.folders,
    required this.tags,
    required this.recentSearches,
    required this.preferences,
  });

  final List<NoteModel> notes;
  final List<FolderModel> folders;
  final List<TagModel> tags;
  final List<String> recentSearches;
  final AppPreferencesModel preferences;

  NotesStoreModel toStore() {
    return NotesStoreModel(
      notes: notes,
      folders: folders,
      tags: tags,
      recentSearches: recentSearches,
      preferences: preferences,
    );
  }

  NotesState copyWith({
    List<NoteModel>? notes,
    List<FolderModel>? folders,
    List<TagModel>? tags,
    List<String>? recentSearches,
    AppPreferencesModel? preferences,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      folders: folders ?? this.folders,
      tags: tags ?? this.tags,
      recentSearches: recentSearches ?? this.recentSearches,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, FolderModel> get folderMap {
    return <String, FolderModel>{
      for (final folder in folders) folder.id: folder,
    };
  }

  FolderModel? folderById(String? folderId) {
    if (folderId == null) {
      return null;
    }
    return folderMap[folderId];
  }

  String get defaultFolderId {
    if (folders.isEmpty) {
      return 'personal';
    }
    return folders.first.id;
  }

  List<NoteModel> get activeNotes {
    return filterNotes();
  }

  List<NoteModel> get trashedNotes {
    return notes.where((note) => note.isDeleted).toList(growable: false)
      ..sort((a, b) =>
          (b.deletedAt ?? b.updatedAt).compareTo(a.deletedAt ?? a.updatedAt));
  }

  List<NoteModel> get archivedNotes {
    return notes
        .where((note) => note.isArchived && !note.isDeleted)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  NoteModel? get featuredPinnedNote {
    final pinned =
        activeNotes.where((note) => note.isPinned).toList(growable: false);
    if (pinned.isEmpty) {
      return null;
    }
    return pinned.first;
  }

  List<NoteModel> get favoriteNotes {
    return filterNotes(favoritesOnly: true);
  }

  List<FolderSummary> get folderSummaries {
    return folders.map((folder) {
      final noteCount = notes.where((note) {
        return !note.isDeleted &&
            !note.isArchived &&
            note.folderId == folder.id;
      }).length;
      return FolderSummary(folder: folder, noteCount: noteCount);
    }).toList(growable: false);
  }

  List<TagSummary> get tagSummaries {
    return tags.map((tag) {
      final noteCount = notes.where((note) {
        if (note.isDeleted || note.isArchived) {
          return false;
        }
        return note.tags.any(
          (entry) => entry.toLowerCase() == tag.label.toLowerCase(),
        );
      }).length;
      return TagSummary(tag: tag, noteCount: noteCount);
    }).toList(growable: false);
  }

  List<NoteModel> topPicks({int limit = 3}) {
    final candidates = notes
        .where((note) => !note.isDeleted && !note.isArchived)
        .toList(growable: false)
      ..sort((a, b) {
        final scoreA = (a.isPinned ? 2 : 0) + (a.isFavorite ? 1 : 0);
        final scoreB = (b.isPinned ? 2 : 0) + (b.isFavorite ? 1 : 0);
        final scoreCompare = scoreB.compareTo(scoreA);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return candidates.take(limit).toList(growable: false);
  }

  List<NoteModel> filterNotes({
    String query = '',
    String? folderId,
    String? tagLabel,
    bool favoritesOnly = false,
    bool pinnedOnly = false,
    bool includeDeleted = false,
    bool includeArchived = false,
    NoteSortOrder? sortOrder,
  }) {
    final effectiveSort = sortOrder ?? preferences.defaultSortOrder;
    final normalizedTag = tagLabel?.trim().toLowerCase();
    final items = notes.where((note) {
      if (!includeDeleted && note.isDeleted) {
        return false;
      }
      if (includeDeleted && !note.isDeleted) {
        return false;
      }
      if (!includeArchived && note.isArchived) {
        return false;
      }
      if (includeArchived && !note.isArchived) {
        return false;
      }
      if (folderId != null && note.folderId != folderId) {
        return false;
      }
      if (favoritesOnly && !note.isFavorite) {
        return false;
      }
      if (pinnedOnly && !note.isPinned) {
        return false;
      }
      if (normalizedTag != null &&
          !note.tags.any((tag) => tag.toLowerCase() == normalizedTag)) {
        return false;
      }

      return note.matchesQuery(
        query,
        folderName: folderById(note.folderId)?.name,
      );
    }).toList(growable: false);

    items.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      switch (effectiveSort) {
        case NoteSortOrder.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case NoteSortOrder.createdDesc:
          return b.createdAt.compareTo(a.createdAt);
        case NoteSortOrder.titleAsc:
          return a.displayTitle.toLowerCase().compareTo(
                b.displayTitle.toLowerCase(),
              );
      }
    });
    return items;
  }
}
