class FolderEntity {
  const FolderEntity({
    required this.id,
    required this.name,
    required this.colorKey,
    required this.emoji,
    required this.createdAt,
    required this.updatedAt,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String colorKey;
  final String emoji;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSystem;

  String get displayName {
    return name;
  }
}
