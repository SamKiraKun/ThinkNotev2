import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/dependency_injection.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../../data/models/app_preferences_model.dart';
import '../../data/models/note_model.dart';
import '../../data/models/notes_store_model.dart';
import '../../domain/entities/note_entity.dart';
import 'notes_state.dart';

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, NotesState>(NotesController.new);

class NotesController extends AsyncNotifier<NotesState> {
  Future<void>? _refreshInFlight;

  @override
  Future<NotesState> build() async {
    return _load();
  }

  Future<void> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      debugPrint(
        '[NotesController] Notes refresh skipped because a load is already in flight.',
      );
      return inFlight;
    }

    final future = _refreshNotes();
    _refreshInFlight = future.whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<void> moveToTrash(String id) async {
    await ref.read(notesRepositoryProvider).moveToTrash(id);
    _scheduleSync();
    _applyNoteMutation(
      id,
      (note) {
        final now = DateTime.now();
        return note.copyWith(
          isDeleted: true,
          deletedAt: now,
          updatedAt: now,
          isPinned: false,
          isArchived: false,
          syncStatus: _pendingMutationStatus(note),
        );
      },
      fallbackToReload: true,
    );
  }

  Future<void> restore(String id) async {
    await ref.read(notesRepositoryProvider).restoreNote(id);
    _scheduleSync();
    _applyNoteMutation(
      id,
      (note) {
        return note.copyWith(
          isDeleted: false,
          deletedAt: null,
          updatedAt: DateTime.now(),
          syncStatus: _pendingMutationStatus(note),
        );
      },
      fallbackToReload: true,
    );
  }

  Future<NoteModel> archive(String id) async {
    final updated = await ref.read(notesRepositoryProvider).archiveNote(id);
    _scheduleSync();
    applyLocalNoteUpsert(updated);
    return updated;
  }

  Future<NoteModel> unarchive(String id) async {
    final updated = await ref.read(notesRepositoryProvider).unarchiveNote(id);
    _scheduleSync();
    applyLocalNoteUpsert(updated);
    return updated;
  }

  Future<void> deletePermanently(String id) async {
    await ref.read(notesRepositoryProvider).deleteNote(id);
    _scheduleSync();
    applyLocalNoteRemoval(id, fallbackToReload: true);
  }

  Future<void> emptyTrash() async {
    final removedIds = state.valueOrNull?.notes
            .where((note) => note.isDeleted)
            .map((note) => note.id)
            .toSet() ??
        <String>{};
    await ref.read(notesRepositoryProvider).emptyTrash();
    _scheduleSync();
    applyLocalNoteRemovals(removedIds, fallbackToReload: true);
  }

  Future<NoteModel> togglePin(String id) async {
    final updated = await ref.read(notesRepositoryProvider).togglePin(id);
    _scheduleSync();
    applyLocalNoteUpsert(updated);
    return updated;
  }

  Future<NoteModel> toggleFavorite(String id) async {
    final updated = await ref.read(notesRepositoryProvider).toggleFavorite(id);
    _scheduleSync();
    applyLocalNoteUpsert(updated);
    return updated;
  }

  Future<void> createFolder(
    String name, {
    String emoji = '\u{1F5C2}\u{FE0F}',
  }) async {
    final folder = await ref
        .read(notesRepositoryProvider)
        .createFolder(name, emoji: emoji);
    _scheduleSync();
    applyLocalFolderUpsert(folder);
  }

  Future<void> renameFolder(String id, String name) async {
    final folder =
        await ref.read(notesRepositoryProvider).renameFolder(id, name);
    _scheduleSync();
    applyLocalFolderUpsert(folder);
  }

  Future<void> deleteFolder(String id) async {
    final current = state.valueOrNull;
    final folder = current?.folderById(id);
    await ref.read(notesRepositoryProvider).deleteFolder(id);
    _scheduleSync();
    if (folder == null || folder.isSystem) {
      ref.invalidateSelf();
      return;
    }

    final fallbackFolderId = current == null
        ? null
        : _fallbackFolderId(
            current.folders.where((item) => item.id != id).toList(),
          );
    final updatedAt = DateTime.now();
    _updateState(
      (notesState) {
        final updatedNotes = notesState.notes.map((note) {
          if (note.folderId != id) {
            return note;
          }

          return note.copyWith(
            folderId: fallbackFolderId,
            updatedAt: updatedAt,
            syncStatus: _pendingMutationStatus(note),
          );
        }).toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return notesState.copyWith(
          folders: notesState.folders
              .where((item) => item.id != id)
              .toList(growable: false),
          notes: updatedNotes,
        );
      },
      fallbackToReload: true,
    );
  }

  Future<void> createTag(String label, {String emoji = '#'}) async {
    final tag =
        await ref.read(notesRepositoryProvider).createTag(label, emoji: emoji);
    _scheduleSync();
    applyLocalTagUpsert(tag);
  }

  Future<void> deleteTag(String id) async {
    final current = state.valueOrNull;
    final tag = current?.tags.where((item) => item.id == id).firstOrNull;
    await ref.read(notesRepositoryProvider).deleteTag(id);
    _scheduleSync();
    if (tag == null) {
      ref.invalidateSelf();
      return;
    }

    final updatedAt = DateTime.now();
    _updateState(
      (notesState) {
        final updatedNotes = notesState.notes.map((note) {
          final containsTag = note.tags.any(
            (entry) => entry.toLowerCase() == tag.label.toLowerCase(),
          );
          if (!containsTag) {
            return note;
          }

          return note.copyWith(
            tags: note.tags
                .where(
                    (entry) => entry.toLowerCase() != tag.label.toLowerCase())
                .toList(growable: false),
            updatedAt: updatedAt,
            syncStatus: _pendingMutationStatus(note),
          );
        }).toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return notesState.copyWith(
          tags: notesState.tags
              .where((item) => item.id != id)
              .toList(growable: false),
          notes: updatedNotes,
        );
      },
      fallbackToReload: true,
    );
  }

  Future<void> saveRecentSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return;
    }
    await ref.read(notesRepositoryProvider).saveRecentSearch(query);
    _updateState(
      (notesState) {
        final entries = <String>[
          trimmedQuery,
          ...notesState.recentSearches.where(
            (entry) => entry.toLowerCase() != trimmedQuery.toLowerCase(),
          ),
        ];
        return notesState.copyWith(
          recentSearches: entries.take(8).toList(growable: false),
        );
      },
      fallbackToReload: true,
    );
  }

  Future<void> clearRecentSearches() async {
    await ref.read(notesRepositoryProvider).clearRecentSearches();
    _updateState(
      (notesState) => notesState.copyWith(recentSearches: const <String>[]),
      fallbackToReload: true,
    );
  }

  Future<void> updatePreferences(AppPreferencesModel preferences) async {
    await ref.read(notesRepositoryProvider).updatePreferences(preferences);
    _updateState(
      (notesState) => notesState.copyWith(preferences: preferences),
      fallbackToReload: true,
    );
  }

  Future<void> replaceStore(NotesStoreModel store) async {
    await ref.read(notesRepositoryProvider).replaceStore(store);
    _scheduleSync();
    final normalizedStore = store.withDefaults();
    state = AsyncData(
      NotesState(
        notes: normalizedStore.notes,
        folders: normalizedStore.folders,
        tags: normalizedStore.tags,
        recentSearches: normalizedStore.recentSearches,
        preferences: normalizedStore.preferences,
      ),
    );
  }

  Future<void> clearAllNotes() async {
    await ref.read(notesRepositoryProvider).clearAllNotes();
    _scheduleSync();
    _updateState(
      (notesState) => notesState.copyWith(notes: const <NoteModel>[]),
      fallbackToReload: true,
    );
  }

  void applyLocalNoteUpsert(NoteModel note) {
    _updateState(
      (notesState) {
        // Autosave updates the visible local state directly so the editor does
        // not trigger a full dashboard reload after each persisted edit.
        final updatedNotes = <NoteModel>[
          note,
          ...notesState.notes.where((item) => item.id != note.id),
        ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return notesState.copyWith(notes: updatedNotes);
      },
      fallbackToReload: false,
    );
  }

  void applyLocalNoteRemoval(
    String noteId, {
    bool fallbackToReload = false,
  }) {
    applyLocalNoteRemovals(
      <String>{noteId},
      fallbackToReload: fallbackToReload,
    );
  }

  void applyLocalNoteRemovals(
    Set<String> noteIds, {
    bool fallbackToReload = false,
  }) {
    if (noteIds.isEmpty) {
      return;
    }

    _updateState(
      (notesState) => notesState.copyWith(
        notes: notesState.notes
            .where((note) => !noteIds.contains(note.id))
            .toList(growable: false),
      ),
      fallbackToReload: fallbackToReload,
    );
  }

  void applyLocalFolderUpsert(FolderModel folder) {
    _updateState(
      (notesState) {
        final existingIndex =
            notesState.folders.indexWhere((item) => item.id == folder.id);
        final updatedFolders = List<FolderModel>.from(notesState.folders);
        if (existingIndex == -1) {
          updatedFolders.add(folder);
        } else {
          updatedFolders[existingIndex] = folder;
        }
        return notesState.copyWith(folders: updatedFolders);
      },
      fallbackToReload: true,
    );
  }

  void applyLocalTagUpsert(TagModel tag) {
    _updateState(
      (notesState) {
        final existingIndex =
            notesState.tags.indexWhere((item) => item.id == tag.id);
        final updatedTags = List<TagModel>.from(notesState.tags);
        if (existingIndex == -1) {
          updatedTags.add(tag);
        } else {
          updatedTags[existingIndex] = tag;
        }
        return notesState.copyWith(tags: updatedTags);
      },
      fallbackToReload: true,
    );
  }

  Future<NotesState> _load() async {
    debugPrint('[NotesController] Dashboard load started.');
    try {
      final store = await ref.read(notesRepositoryProvider).loadStore();
      final notesState = NotesState(
        notes: store.notes,
        folders: store.folders,
        tags: store.tags,
        recentSearches: store.recentSearches,
        preferences: store.preferences,
      );
      debugPrint(
        '[NotesController] Dashboard load succeeded with ${store.notes.length} notes, ${store.folders.length} folders, and ${store.tags.length} tags.',
      );
      return notesState;
    } catch (error, stackTrace) {
      debugPrint(
        '[NotesController] Dashboard load failed with ${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _refreshNotes() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void _scheduleSync() {
    unawaited(ref.read(syncControllerProvider.notifier).scheduleSync());
  }

  void _applyNoteMutation(
    String noteId,
    NoteModel Function(NoteModel note) transform, {
    required bool fallbackToReload,
  }) {
    _updateState(
      (notesState) {
        final index = notesState.notes.indexWhere((note) => note.id == noteId);
        if (index == -1) {
          return notesState;
        }

        final updatedNote = transform(notesState.notes[index]);
        final updatedNotes = List<NoteModel>.from(notesState.notes)
          ..removeAt(index)
          ..insert(0, updatedNote)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return notesState.copyWith(notes: updatedNotes);
      },
      fallbackToReload: fallbackToReload,
    );
  }

  void _updateState(
    NotesState Function(NotesState notesState) transform, {
    required bool fallbackToReload,
  }) {
    final current = state.valueOrNull;
    if (current == null) {
      if (fallbackToReload) {
        ref.invalidateSelf();
      }
      return;
    }

    state = AsyncData(transform(current));
  }

  NoteSyncStatus _pendingMutationStatus(NoteModel note) {
    return note.remoteId == null
        ? NoteSyncStatus.pendingCreate
        : NoteSyncStatus.pendingUpdate;
  }

  String _fallbackFolderId(List<FolderModel> folders) {
    if (folders.isEmpty) {
      return 'personal';
    }
    return folders.first.id;
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

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
