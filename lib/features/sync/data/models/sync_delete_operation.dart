import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

enum SyncEntityType {
  note,
  folder,
  tag,
}

extension SyncEntityTypeX on SyncEntityType {
  String get storageValue {
    switch (this) {
      case SyncEntityType.note:
        return 'note';
      case SyncEntityType.folder:
        return 'folder';
      case SyncEntityType.tag:
        return 'tag';
    }
  }

  String get deleteFieldName {
    switch (this) {
      case SyncEntityType.note:
        return 'deleted_notes';
      case SyncEntityType.folder:
        return 'deleted_folders';
      case SyncEntityType.tag:
        return 'deleted_tags';
    }
  }

  static SyncEntityType fromStorage(String value) {
    switch (value) {
      case 'note':
        return SyncEntityType.note;
      case 'folder':
        return SyncEntityType.folder;
      case 'tag':
        return SyncEntityType.tag;
      default:
        throw StateError('Unsupported sync entity type "$value".');
    }
  }
}

class SyncDeleteOperation {
  const SyncDeleteOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.deletedAt,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory SyncDeleteOperation.forEntity({
    required SyncEntityType entityType,
    required String entityId,
    required DateTime deletedAt,
  }) {
    final createdAt = DateTime.now().toUtc();
    return SyncDeleteOperation(
      id: _queueIdFor(entityType, entityId),
      entityType: entityType,
      entityId: entityId,
      deletedAt: deletedAt.toUtc(),
      createdAt: createdAt,
    );
  }

  factory SyncDeleteOperation.fromRow(Row row) {
    final payload =
        jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
    return SyncDeleteOperation(
      id: row['id'] as String,
      entityType: SyncEntityTypeX.fromStorage(row['entity_type'] as String),
      entityId: row['entity_id'] as String,
      deletedAt: DateTime.parse(payload['deleted_at'] as String).toUtc(),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error'] as String?,
    );
  }

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final DateTime deletedAt;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  Map<String, dynamic> toPayloadJson() {
    return <String, dynamic>{
      'id': entityId,
      'deleted_at': deletedAt.toIso8601String(),
    };
  }

  String get payloadJsonString => jsonEncode(toPayloadJson());

  SyncDeleteOperation copyWith({
    int? retryCount,
    Object? lastError = _sentinel,
  }) {
    return SyncDeleteOperation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      deletedAt: deletedAt,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
    );
  }

  static String queueIdFor(SyncEntityType entityType, String entityId) {
    return _queueIdFor(entityType, entityId);
  }
}

String _queueIdFor(SyncEntityType entityType, String entityId) {
  return '${entityType.storageValue}:$entityId:delete';
}

const Object _sentinel = Object();
