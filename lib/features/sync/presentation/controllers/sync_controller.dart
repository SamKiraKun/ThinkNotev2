import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/network/authenticated_api_client.dart';
import '../../../auth/auth_providers.dart';
import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import '../../../notes/data/datasources/notes_local_datasource.dart';
import '../../../notes/data/models/note_model.dart';
import '../../../notes/data/models/notes_store_model.dart';
import '../../../notes/domain/entities/note_entity.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../data/models/sync_delete_operation.dart';

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});

class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.lastError,
    this.nextRetryAt,
    this.failureCount = 0,
  });

  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final DateTime? nextRetryAt;
  final int failureCount;

  SyncState copyWith({
    bool? isSyncing,
    Object? lastSyncedAt = _syncSentinel,
    Object? lastError = _syncSentinel,
    Object? nextRetryAt = _syncSentinel,
    int? failureCount,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: identical(lastSyncedAt, _syncSentinel)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      lastError: identical(lastError, _syncSentinel)
          ? this.lastError
          : lastError as String?,
      nextRetryAt: identical(nextRetryAt, _syncSentinel)
          ? this.nextRetryAt
          : nextRetryAt as DateTime?,
      failureCount: failureCount ?? this.failureCount,
    );
  }
}

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._ref) : super(const SyncState()) {
    unawaited(_restoreSyncMetadata());
  }

  final Ref _ref;
  Future<void>? _inFlight;

  Future<void> scheduleSync({
    bool forceFullPull = false,
    bool rethrowOnError = false,
  }) {
    return syncNow(
      forceFullPull: forceFullPull,
      rethrowOnError: rethrowOnError,
    );
  }

  Future<void> syncNow({
    bool forceFullPull = false,
    bool rethrowOnError = false,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _runSync(
      forceFullPull: forceFullPull,
      rethrowOnError: rethrowOnError,
    );
    _inFlight = future.whenComplete(() {
      _inFlight = null;
    });
    return _inFlight!;
  }

  Future<void> _restoreSyncMetadata() async {
    if (!AppEnv.enableExperimentalSync) {
      return;
    }

    final localDataSource = _ref.read(notesLocalDataSourceProvider);
    final rawLastSyncedAt =
        await localDataSource.readSyncState(_lastServerSyncKey);
    final rawNextRetryAt = await localDataSource.readSyncState(_nextRetryAtKey);
    final rawFailureCount =
        await localDataSource.readSyncState(_failureCountKey);

    state = state.copyWith(
      lastSyncedAt: DateTime.tryParse(rawLastSyncedAt ?? ''),
      nextRetryAt: DateTime.tryParse(rawNextRetryAt ?? ''),
      failureCount: int.tryParse(rawFailureCount ?? '') ?? 0,
    );
  }

  Future<void> _runSync({
    required bool forceFullPull,
    required bool rethrowOnError,
  }) async {
    if (!AppEnv.enableExperimentalSync) {
      return;
    }

    final session = _ref.read(currentAuthSessionProvider);
    if (session == null) {
      return;
    }

    final localDataSource = _ref.read(notesLocalDataSourceProvider);
    final nextRetryAt = await _readNextRetryAt(localDataSource);
    if (!forceFullPull &&
        nextRetryAt != null &&
        DateTime.now().toUtc().isBefore(nextRetryAt)) {
      state = state.copyWith(nextRetryAt: nextRetryAt);
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      lastError: null,
      nextRetryAt: null,
    );

    List<SyncDeleteOperation> pendingDeletes = const <SyncDeleteOperation>[];

    try {
      final apiClient = _ref.read(authenticatedApiClientProvider);
      final localStore = await localDataSource.readStore();
      pendingDeletes = await localDataSource.readPendingDeleteOperations();
      final since = forceFullPull
          ? null
          : await localDataSource.readSyncState(_lastServerSyncKey);

      await apiClient.postJson(
        '/sync/push',
        body: _buildPushBody(localStore, pendingDeletes),
      );

      await localDataSource.clearPendingDeleteOperations(
        pendingDeletes.map((operation) => operation.id).toList(growable: false),
      );

      final pullResponse = await apiClient.getJson(
        '/sync/pull',
        queryParameters:
            since == null ? null : <String, String>{'since': since},
      );
      final payload = SyncPullPayload.fromJson(
        pullResponse['data'] as Map<String, dynamic>,
      );

      final mergedStore = _mergeStore(localStore, payload);
      await localDataSource.writeStore(mergedStore);
      await localDataSource.clearPendingDeleteOperations(
        _queueIdsForRemoteDeletes(payload),
      );
      await localDataSource.writeSyncState(
        _lastServerSyncKey,
        payload.serverTime.toIso8601String(),
      );
      await localDataSource.deleteSyncState(_nextRetryAtKey);
      await localDataSource.deleteSyncState(_failureCountKey);

      _ref.invalidate(notesControllerProvider);
      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: payload.serverTime,
        lastError: null,
        nextRetryAt: null,
        failureCount: 0,
      );
    } catch (error) {
      final errorMessage =
          error is ApiException ? error.message : error.toString();
      final failureCount = state.failureCount + 1;
      final retryAt = _calculateNextRetryAt(failureCount);

      await localDataSource.markDeleteOperationsFailed(
        pendingDeletes.map((operation) => operation.id).toList(growable: false),
        errorMessage,
      );
      await localDataSource.writeSyncState(
        _failureCountKey,
        failureCount.toString(),
      );
      await localDataSource.writeSyncState(
        _nextRetryAtKey,
        retryAt.toIso8601String(),
      );

      state = state.copyWith(
        isSyncing: false,
        lastError: errorMessage,
        nextRetryAt: retryAt,
        failureCount: failureCount,
      );

      if (rethrowOnError) {
        rethrow;
      }
    }
  }

  NotesStoreModel _mergeStore(
      NotesStoreModel localStore, SyncPullPayload payload) {
    final deletedNoteIds = payload.deletedNotes.map((item) => item.id).toSet();
    final deletedFolderIds =
        payload.deletedFolders.map((item) => item.id).toSet();
    final deletedTagIds = payload.deletedTags.map((item) => item.id).toSet();

    final mergedNotes = <String, NoteModel>{
      for (final note in localStore.notes)
        if (!deletedNoteIds.contains(note.id)) note.id: note,
    };

    for (final remoteNote in payload.notes) {
      if (deletedNoteIds.contains(remoteNote.id)) {
        continue;
      }

      final localNote = mergedNotes[remoteNote.id];
      if (localNote == null ||
          localNote.syncStatus == NoteSyncStatus.synced ||
          !localNote.updatedAt.isAfter(remoteNote.updatedAt)) {
        mergedNotes[remoteNote.id] = remoteNote.copyWith(
          remoteId: remoteNote.remoteId ?? remoteNote.id,
          syncStatus: NoteSyncStatus.synced,
          lastSyncedAt: payload.serverTime,
        );
      }
    }

    final defaultFolders = localStore.folders
        .where((folder) => folder.isSystem)
        .toList(growable: false);
    final mergedFolders = <FolderModel>[
      ...defaultFolders,
      ...payload.folders.where(
        (folder) =>
            !deletedFolderIds.contains(folder.id) &&
            !defaultFolders.any((item) => item.id == folder.id),
      ),
    ];

    final localDefaultTags = localStore.tags
        .where((tag) => _defaultTagIds.contains(tag.id))
        .toList(growable: false);
    final mergedTags = <TagModel>[
      ...localDefaultTags,
      ...payload.tags.where((remoteTag) {
        return !deletedTagIds.contains(remoteTag.id) &&
            !localDefaultTags.any(
              (localTag) =>
                  localTag.label.toLowerCase() == remoteTag.label.toLowerCase(),
            );
      }),
    ];

    return localStore.copyWith(
      notes: mergedNotes.values.toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      folders: mergedFolders,
      tags: mergedTags,
    );
  }
}

class SyncPullPayload {
  const SyncPullPayload({
    required this.serverTime,
    required this.notes,
    required this.folders,
    required this.tags,
    required this.deletedNotes,
    required this.deletedFolders,
    required this.deletedTags,
  });

  factory SyncPullPayload.fromJson(Map<String, dynamic> json) {
    return SyncPullPayload(
      serverTime: DateTime.parse(json['server_time'] as String),
      notes: (json['notes'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(NoteModel.fromJson)
          .toList(growable: false),
      folders: (json['folders'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FolderModel.fromJson)
          .toList(growable: false),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TagModel.fromJson)
          .toList(growable: false),
      deletedNotes:
          _readDeletedEntities(json['deleted_notes'] as List<dynamic>?),
      deletedFolders:
          _readDeletedEntities(json['deleted_folders'] as List<dynamic>?),
      deletedTags: _readDeletedEntities(json['deleted_tags'] as List<dynamic>?),
    );
  }

  final DateTime serverTime;
  final List<NoteModel> notes;
  final List<FolderModel> folders;
  final List<TagModel> tags;
  final List<DeletedSyncEntity> deletedNotes;
  final List<DeletedSyncEntity> deletedFolders;
  final List<DeletedSyncEntity> deletedTags;
}

class DeletedSyncEntity {
  const DeletedSyncEntity({
    required this.id,
    required this.deletedAt,
  });

  factory DeletedSyncEntity.fromJson(Map<String, dynamic> json) {
    return DeletedSyncEntity(
      id: json['id'] as String,
      deletedAt: DateTime.parse(json['deleted_at'] as String).toUtc(),
    );
  }

  final String id;
  final DateTime deletedAt;
}

List<DeletedSyncEntity> _readDeletedEntities(List<dynamic>? rawItems) {
  return (rawItems ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map(DeletedSyncEntity.fromJson)
      .toList(growable: false);
}

Map<String, dynamic> _buildPushBody(
  NotesStoreModel localStore,
  List<SyncDeleteOperation> pendingDeletes,
) {
  final deletedNotes = <Map<String, dynamic>>[];
  final deletedFolders = <Map<String, dynamic>>[];
  final deletedTags = <Map<String, dynamic>>[];

  for (final operation in pendingDeletes) {
    switch (operation.entityType) {
      case SyncEntityType.note:
        deletedNotes.add(operation.toPayloadJson());
      case SyncEntityType.folder:
        deletedFolders.add(operation.toPayloadJson());
      case SyncEntityType.tag:
        deletedTags.add(operation.toPayloadJson());
    }
  }

  return <String, dynamic>{
    'notes': localStore.notes
        .where((note) => note.syncStatus != NoteSyncStatus.synced)
        .map(_noteToPushJson)
        .toList(growable: false),
    'folders': localStore.folders
        .where((folder) => !folder.isSystem)
        .map(_folderToPushJson)
        .toList(growable: false),
    'tags': localStore.tags
        .where((tag) => !_defaultTagIds.contains(tag.id))
        .map(_tagToPushJson)
        .toList(growable: false),
    'deleted_notes': deletedNotes,
    'deleted_folders': deletedFolders,
    'deleted_tags': deletedTags,
  };
}

List<String> _queueIdsForRemoteDeletes(SyncPullPayload payload) {
  return <String>[
    ...payload.deletedNotes.map(
      (item) => SyncDeleteOperation.queueIdFor(SyncEntityType.note, item.id),
    ),
    ...payload.deletedFolders.map(
      (item) => SyncDeleteOperation.queueIdFor(SyncEntityType.folder, item.id),
    ),
    ...payload.deletedTags.map(
      (item) => SyncDeleteOperation.queueIdFor(SyncEntityType.tag, item.id),
    ),
  ];
}

Future<DateTime?> _readNextRetryAt(NotesLocalDataSource localDataSource) async {
  final rawValue = await localDataSource.readSyncState(_nextRetryAtKey);
  return DateTime.tryParse(rawValue ?? '')?.toUtc();
}

DateTime _calculateNextRetryAt(int failureCount) {
  const maxDelaySeconds = 15 * 60;
  final exponent = failureCount <= 1 ? 0 : failureCount - 1;
  final delaySeconds = (30 * (1 << exponent)).clamp(30, maxDelaySeconds);
  return DateTime.now().toUtc().add(Duration(seconds: delaySeconds));
}

Map<String, dynamic> _noteToPushJson(NoteModel note) {
  return <String, dynamic>{
    'id': note.remoteId ?? note.id,
    'title': note.title,
    'content': note.content,
    'folder_id': note.folderId,
    'tags': note.tags,
    'is_pinned': note.isPinned,
    'is_favorite': note.isFavorite,
    'is_archived': note.isArchived,
    'is_deleted': note.isDeleted,
    'created_at': note.createdAt.toIso8601String(),
    'updated_at': note.updatedAt.toIso8601String(),
    'deleted_at': note.deletedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _folderToPushJson(FolderModel folder) {
  return <String, dynamic>{
    'id': folder.id,
    'name': folder.name,
    'color_key': folder.colorKey,
    'emoji': folder.emoji,
    'created_at': folder.createdAt.toIso8601String(),
    'updated_at': folder.updatedAt.toIso8601String(),
  };
}

Map<String, dynamic> _tagToPushJson(TagModel tag) {
  return <String, dynamic>{
    'id': tag.id,
    'label': tag.label,
    'emoji': tag.emoji,
    'created_at': tag.createdAt.toIso8601String(),
    'updated_at': tag.updatedAt.toIso8601String(),
  };
}

const String _lastServerSyncKey = 'last_server_sync_at';
const String _nextRetryAtKey = 'sync_retry_after';
const String _failureCountKey = 'sync_failure_count';
final Set<String> _defaultTagIds = <String>{
  for (final tag in TagModel.defaults()) tag.id,
};
const Object _syncSentinel = Object();
