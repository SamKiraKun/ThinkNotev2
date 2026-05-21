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
    this.isDeleted = false,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;
  final List<String> tags;
  final bool isPinned;
  final bool isFavorite;
  final bool isDeleted;
  final DateTime? deletedAt;

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
