import '../../domain/entities/note_entity.dart';

class NoteModel extends NoteEntity {
  const NoteModel({
    required super.id,
    super.remoteId,
    required super.title,
    required super.content,
    required super.createdAt,
    required super.updatedAt,
    super.folderId,
    super.tags,
    super.isPinned,
    super.isFavorite,
    super.isArchived,
    super.isDeleted,
    super.deletedAt,
    super.syncStatus,
    super.lastSyncedAt,
    super.serverVersion,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      remoteId: json['remote_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isPinned: json['is_pinned'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      folderId: json['folder_id'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((tag) => tag.toString())
          .toList(growable: false),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      syncStatus:
          NoteSyncStatusX.fromStorage(json['sync_status'] as String?),
      lastSyncedAt: json['last_synced_at'] == null
          ? null
          : DateTime.parse(json['last_synced_at'] as String),
      serverVersion: json['server_version'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'remote_id': remoteId,
      'title': title,
      'content': content,
      'is_pinned': isPinned,
      'is_favorite': isFavorite,
      'is_archived': isArchived,
      'is_deleted': isDeleted,
      'folder_id': folderId,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.storageValue,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'server_version': serverVersion,
    };
  }

  NoteModel copyWith({
    Object? remoteId = _sentinel,
    String? title,
    String? content,
    Object? folderId = _sentinel,
    List<String>? tags,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
    NoteSyncStatus? syncStatus,
    Object? lastSyncedAt = _sentinel,
    int? serverVersion,
  }) {
    return NoteModel(
      id: id,
      remoteId: identical(remoteId, _sentinel)
          ? this.remoteId
          : remoteId as String?,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId:
          identical(folderId, _sentinel) ? this.folderId : folderId as String?,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: identical(lastSyncedAt, _sentinel)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  bool matchesQuery(String query, {String? folderName}) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystacks = <String>[
      title,
      content,
      folderName ?? '',
      ...tags,
    ].map((value) => value.toLowerCase());

    return haystacks.any((value) => value.contains(normalizedQuery));
  }
}

const Object _sentinel = Object();
