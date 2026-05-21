class FolderEntity {
  const FolderEntity({
    required this.id,
    required this.name,
    required this.colorKey,
    required this.emoji,
    required this.createdAt,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String colorKey;
  final String emoji;
  final DateTime createdAt;
  final bool isSystem;

  String get displayName {
    if (emoji.trim().isEmpty) {
      return name;
    }

    return '$name $emoji';
  }
}
