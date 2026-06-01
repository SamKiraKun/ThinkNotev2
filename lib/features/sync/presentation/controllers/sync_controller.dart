import 'dart:async';

import 'package:flutter/foundation.dart';
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

enum SyncErrorType {
  noInternet,
  dns,
  tls,
  timeout,
  serverUnreachable,
  localDatabase,
  authentication,
  authorization,
  validation,
  conflict,
  rateLimited,
  api,
  invalidResponse,
  unknown,
}

class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.lastError,
    this.lastErrorType,
    this.nextRetryAt,
    this.failureCount = 0,
  });

  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final SyncErrorType? lastErrorType;
  final DateTime? nextRetryAt;
  final int failureCount;

  SyncState copyWith({
    bool? isSyncing,
    Object? lastSyncedAt = _syncSentinel,
    Object? lastError = _syncSentinel,
    Object? lastErrorType = _syncSentinel,
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
      lastErrorType: identical(lastErrorType, _syncSentinel)
          ? this.lastErrorType
          : lastErrorType as SyncErrorType?,
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
      debugPrint(
        '[SyncController] Sync skipped because another sync is already running.',
      );
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
      debugPrint('[SyncController] Sync skipped because sync is disabled.');
      return;
    }

    final session = _ref.read(currentAuthSessionProvider);
    if (session == null) {
      debugPrint('[SyncController] Sync skipped because there is no session.');
      return;
    }

    debugPrint(
      '[SyncController] Sync started for ${session.uid}. forceFullPull=$forceFullPull',
    );

    final localDataSource = _ref.read(notesLocalDataSourceProvider);
    final nextRetryAt = await _readNextRetryAt(localDataSource);
    if (!forceFullPull &&
        nextRetryAt != null &&
        DateTime.now().toUtc().isBefore(nextRetryAt)) {
      debugPrint(
        '[SyncController] Sync skipped until ${nextRetryAt.toIso8601String()} because retry backoff is active.',
      );
      state = state.copyWith(nextRetryAt: nextRetryAt);
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      lastError: null,
      lastErrorType: null,
      nextRetryAt: null,
    );

    List<SyncDeleteOperation> pendingDeletes = const <SyncDeleteOperation>[];
    Map<String, DateTime> pushedNoteVersions = const <String, DateTime>{};

    try {
      final apiClient = _ref.read(authenticatedApiClientProvider);
      final localStore = await localDataSource.readStore();
      pendingDeletes = await localDataSource.readPendingDeleteOperations();
      pushedNoteVersions = _pushedNoteVersions(localStore);
      final since = forceFullPull
          ? null
          : await localDataSource.readSyncState(_lastServerSyncKey);

      debugPrint('[SyncController] Checking backend health before sync.');
      await apiClient.verifyBackendHealth();

      debugPrint(
        '[SyncController] Sync push started with ${pushedNoteVersions.length} dirty notes and ${pendingDeletes.length} queued deletes.',
      );

      await apiClient.postJson(
        '/sync/push',
        body: _buildPushBody(localStore, pendingDeletes),
      );

      debugPrint('[SyncController] Sync push succeeded. Starting pull.');

      final pullResponse = await apiClient.getJson(
        '/sync/pull',
        queryParameters:
            since == null ? null : <String, String>{'since': since},
      );
      final payload = SyncPullPayload.fromJson(
        pullResponse['data'] as Map<String, dynamic>,
      );

      final latestLocalStore = await localDataSource.readStore();
      final acknowledgedStore = _acknowledgePushedNotes(
        latestLocalStore,
        pushedNoteVersions: pushedNoteVersions,
        syncedAt: payload.serverTime,
      );
      final mergedStore = _mergeStore(acknowledgedStore, payload);
      await localDataSource.commitSyncResult(
        store: mergedStore,
        queueIdsToClear: <String>[
          ...pendingDeletes.map((operation) => operation.id),
          ..._queueIdsForRemoteDeletes(payload),
        ],
        syncStateUpdates: <String, String>{
          _lastServerSyncKey: payload.serverTime.toIso8601String(),
        },
        syncStateDeletes: const <String>[
          _nextRetryAtKey,
          _failureCountKey,
        ],
      );

      _ref.invalidate(notesControllerProvider);
      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: payload.serverTime,
        lastError: null,
        lastErrorType: null,
        nextRetryAt: null,
        failureCount: 0,
      );
      debugPrint(
        '[SyncController] Sync succeeded at ${payload.serverTime.toIso8601String()}.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SyncController] Sync failed with ${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      final failure = _classifySyncFailure(error);
      final failureCount = state.failureCount + 1;
      final retryAt = _calculateNextRetryAt(failureCount);

      try {
        await localDataSource.recordSyncFailure(
          queueIds: pendingDeletes
              .map((operation) => operation.id)
              .toList(growable: false),
          errorMessage: failure.message,
          syncStateUpdates: <String, String>{
            _failureCountKey: failureCount.toString(),
            _nextRetryAtKey: retryAt.toIso8601String(),
          },
        );
      } catch (persistenceError, persistenceStackTrace) {
        debugPrint(
          '[SyncController] Failed to persist sync failure metadata after ${persistenceError.runtimeType}: $persistenceError',
        );
        debugPrintStack(stackTrace: persistenceStackTrace);
      }

      state = state.copyWith(
        isSyncing: false,
        lastError: failure.message,
        lastErrorType: failure.type,
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
    final fallbackFolderId =
        defaultFolders.isEmpty ? null : defaultFolders.first.id;
    final availableFolderIds = mergedFolders
        .map((folder) => folder.id)
        .toSet();

    NoteModel normalizePulledNote(NoteModel note) {
      if (fallbackFolderId == null) {
        return note;
      }

      final folderId = note.folderId;
      if (folderId == null || !availableFolderIds.contains(folderId)) {
        return note.copyWith(folderId: fallbackFolderId);
      }

      return note;
    }

    final mergedNotes = <String, NoteModel>{
      for (final note in localStore.notes)
        if (!deletedNoteIds.contains(note.id)) note.id: note,
    };

    for (final remoteNote in payload.notes) {
      if (deletedNoteIds.contains(remoteNote.id)) {
        continue;
      }

      final normalizedRemoteNote = normalizePulledNote(remoteNote);

      final localNote = mergedNotes[normalizedRemoteNote.id];
      if (localNote == null ||
          localNote.syncStatus == NoteSyncStatus.synced ||
          !localNote.updatedAt.isAfter(normalizedRemoteNote.updatedAt)) {
        mergedNotes[normalizedRemoteNote.id] = normalizedRemoteNote.copyWith(
          remoteId:
              normalizedRemoteNote.remoteId ?? normalizedRemoteNote.id,
          syncStatus: NoteSyncStatus.synced,
          lastSyncedAt: payload.serverTime,
        );
      }
    }

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

String describeSyncErrorType(SyncErrorType? type) {
  return switch (type) {
    SyncErrorType.noInternet => 'No internet connection',
    SyncErrorType.dns => 'DNS issue',
    SyncErrorType.tls => 'Connection security issue',
    SyncErrorType.timeout => 'Connection timeout',
    SyncErrorType.serverUnreachable => 'Server unreachable',
    SyncErrorType.localDatabase => 'Local database issue',
    SyncErrorType.authentication => 'Authentication issue',
    SyncErrorType.authorization => 'Permission issue',
    SyncErrorType.validation => 'Sync data issue',
    SyncErrorType.conflict => 'Sync conflict',
    SyncErrorType.rateLimited => 'Retry later',
    SyncErrorType.api => 'Server issue',
    SyncErrorType.invalidResponse => 'Invalid server response',
    SyncErrorType.unknown || null => 'Sync issue',
  };
}

_SyncFailure _classifySyncFailure(Object error) {
  if (error is ApiException) {
    if (error.kind == ApiFailureKind.authentication) {
      return const _SyncFailure(
        type: SyncErrorType.authentication,
        message:
            'Your session expired. Sign in again to resume sync. Local notes remain on this device.',
      );
    }

    final networkFailure = _networkFailureForApiError(error);
    if (networkFailure != null) {
      return networkFailure;
    }

    return _SyncFailure(
      type: _syncErrorTypeForApiFailure(error.kind),
      message: error.message.isEmpty
          ? 'The server could not complete sync. Your changes stay queued and will retry automatically.'
          : error.message,
    );
  }

  if (_looksLikeLocalDatabaseError(error)) {
    return const _SyncFailure(
      type: SyncErrorType.localDatabase,
      message:
          'Sync could not update the local database. Your local notes are still available and ThinkNote will retry automatically.',
    );
  }

  return const _SyncFailure(
    type: SyncErrorType.unknown,
    message:
        'Sync could not finish. Your local notes are still available and ThinkNote will retry automatically.',
  );
}

_SyncFailure? _networkFailureForApiError(ApiException error) {
  return switch (error.kind) {
    ApiFailureKind.noInternet => const _SyncFailure(
        type: SyncErrorType.noInternet,
        message:
            'No internet connection is available. Your changes stay queued and will retry automatically.',
      ),
    ApiFailureKind.dns => const _SyncFailure(
        type: SyncErrorType.dns,
        message:
            'ThinkNote could not resolve the backend address. Your changes stay queued and will retry automatically.',
      ),
    ApiFailureKind.tls => const _SyncFailure(
        type: SyncErrorType.tls,
        message:
            'ThinkNote could not establish a secure HTTPS connection to the backend. Your changes stay queued and will retry automatically.',
      ),
    ApiFailureKind.timeout => const _SyncFailure(
        type: SyncErrorType.timeout,
        message:
            'The backend took too long to respond. Your changes stay queued and will retry automatically.',
      ),
    ApiFailureKind.serverUnreachable => const _SyncFailure(
        type: SyncErrorType.serverUnreachable,
        message:
            'ThinkNote could not reach the server. Your changes stay queued and will retry automatically.',
      ),
    _ => null,
  };
}

SyncErrorType _syncErrorTypeForApiFailure(ApiFailureKind kind) {
  return switch (kind) {
    ApiFailureKind.authentication => SyncErrorType.authentication,
    ApiFailureKind.authorization => SyncErrorType.authorization,
    ApiFailureKind.validation => SyncErrorType.validation,
    ApiFailureKind.conflict => SyncErrorType.conflict,
    ApiFailureKind.rateLimited => SyncErrorType.rateLimited,
    ApiFailureKind.server => SyncErrorType.api,
    ApiFailureKind.invalidResponse => SyncErrorType.invalidResponse,
    ApiFailureKind.notFound => SyncErrorType.api,
    ApiFailureKind.noInternet ||
    ApiFailureKind.dns ||
    ApiFailureKind.tls ||
    ApiFailureKind.timeout ||
    ApiFailureKind.serverUnreachable =>
      SyncErrorType.serverUnreachable,
    ApiFailureKind.unknown => SyncErrorType.unknown,
  };
}

bool _looksLikeLocalDatabaseError(Object error) {
  if (error is StateError) {
    return true;
  }

  final normalizedMessage = error.toString().toLowerCase();
  return normalizedMessage.contains('sqlite') ||
      normalizedMessage.contains('database') ||
      normalizedMessage.contains('transaction') ||
      normalizedMessage.contains('begin immediate');
}

class _SyncFailure {
  const _SyncFailure({
    required this.type,
    required this.message,
  });

  final SyncErrorType type;
  final String message;
}

Map<String, DateTime> _pushedNoteVersions(NotesStoreModel localStore) {
  return <String, DateTime>{
    for (final note in localStore.notes)
      if (note.syncStatus != NoteSyncStatus.synced) note.id: note.updatedAt,
  };
}

NotesStoreModel _acknowledgePushedNotes(
  NotesStoreModel localStore, {
  required Map<String, DateTime> pushedNoteVersions,
  required DateTime syncedAt,
}) {
  if (pushedNoteVersions.isEmpty) {
    return localStore;
  }

  final updatedNotes = localStore.notes.map((note) {
    final pushedUpdatedAt = pushedNoteVersions[note.id];
    if (pushedUpdatedAt == null) {
      return note;
    }

    if (!note.updatedAt.isAtSameMomentAs(pushedUpdatedAt)) {
      return note;
    }

    return note.copyWith(
      remoteId: note.remoteId ?? note.id,
      syncStatus: NoteSyncStatus.synced,
      lastSyncedAt: syncedAt,
    );
  }).toList(growable: false);

  return localStore.copyWith(notes: updatedNotes);
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
  final localOnlyFolderIds = localStore.folders
      .where((folder) => folder.isSystem)
      .map((folder) => folder.id)
      .toSet();
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
      .map((note) => _noteToPushJson(note, localOnlyFolderIds))
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

Map<String, dynamic> _noteToPushJson(
  NoteModel note,
  Set<String> localOnlyFolderIds,
) {
  return <String, dynamic>{
    'id': note.remoteId ?? note.id,
    'title': note.title,
    'content': note.content,
    'folder_id': localOnlyFolderIds.contains(note.folderId)
        ? null
        : note.folderId,
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
