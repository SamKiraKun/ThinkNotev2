class TagEntity {
  const TagEntity({
    required this.id,
    required this.label,
    required this.createdAt,
    this.emoji = '',
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final String emoji;

  String get displayLabel {
    if (emoji.trim().isEmpty) {
      return label;
    }

    return '$emoji $label';
  }
}
