import '../../domain/entities/note_entity.dart';

class NoteModel extends NoteEntity {
  const NoteModel({
    required super.id,
    required super.title,
    required super.content,
    required super.createdAt,
    required super.updatedAt,
    super.folderId,
    super.tags,
    super.isPinned,
    super.isFavorite,
    super.isDeleted,
    super.deletedAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isPinned: json['is_pinned'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
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
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'is_pinned': isPinned,
      'is_favorite': isFavorite,
      'is_deleted': isDeleted,
      'folder_id': folderId,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  NoteModel copyWith({
    String? title,
    String? content,
    Object? folderId = _sentinel,
    List<String>? tags,
    bool? isPinned,
    bool? isFavorite,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) {
    return NoteModel(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId:
          identical(folderId, _sentinel) ? this.folderId : folderId as String?,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
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
