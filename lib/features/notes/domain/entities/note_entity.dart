enum NoteSyncStatus {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  failed,
}

extension NoteSyncStatusX on NoteSyncStatus {
  String get storageValue {
    switch (this) {
      case NoteSyncStatus.synced:
        return 'synced';
      case NoteSyncStatus.pendingCreate:
        return 'pending_create';
      case NoteSyncStatus.pendingUpdate:
        return 'pending_update';
      case NoteSyncStatus.pendingDelete:
        return 'pending_delete';
      case NoteSyncStatus.failed:
        return 'failed';
    }
  }

  String get label {
    switch (this) {
      case NoteSyncStatus.synced:
        return 'Synced';
      case NoteSyncStatus.pendingCreate:
      case NoteSyncStatus.pendingUpdate:
      case NoteSyncStatus.pendingDelete:
        return 'Pending sync';
      case NoteSyncStatus.failed:
        return 'Sync failed';
    }
  }

  static NoteSyncStatus fromStorage(String? value) {
    switch (value) {
      case 'pending_create':
        return NoteSyncStatus.pendingCreate;
      case 'pending_update':
        return NoteSyncStatus.pendingUpdate;
      case 'pending_delete':
        return NoteSyncStatus.pendingDelete;
      case 'failed':
        return NoteSyncStatus.failed;
      case 'synced':
      default:
        return NoteSyncStatus.synced;
    }
  }
}

class NoteEntity {
  const NoteEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.tags = const <String>[],
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.deletedAt,
    this.remoteId,
    this.syncStatus = NoteSyncStatus.synced,
    this.lastSyncedAt,
    this.serverVersion = 0,
  });

  final String id;
  final String? remoteId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;
  final List<String> tags;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isDeleted;
  final DateTime? deletedAt;
  final NoteSyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final int serverVersion;

  bool get hasMeaningfulContent {
    return title.trim().isNotEmpty || content.trim().isNotEmpty;
  }

  String get displayTitle {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }

    final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalizedContent.isEmpty) {
      return 'Untitled note';
    }

    if (normalizedContent.length <= 42) {
      return normalizedContent;
    }

    return '${normalizedContent.substring(0, 42).trimRight()}...';
  }

  String get excerpt {
    final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalizedContent.isEmpty) {
      return 'Start writing to build this note.';
    }

    if (normalizedContent.length <= 96) {
      return normalizedContent;
    }

    return '${normalizedContent.substring(0, 96).trimRight()}...';
  }
}
