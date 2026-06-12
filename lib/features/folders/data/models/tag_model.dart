import '../../domain/entities/tag_entity.dart';

class TagModel extends TagEntity {
  const TagModel({
    required super.id,
    required super.label,
    required super.createdAt,
    required super.updatedAt,
    super.emoji,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: json['id'] as String,
      label: json['label'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.parse(json['updated_at'] as String),
      emoji: json['emoji'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'emoji': emoji,
    };
  }

  static List<TagModel> defaults() {
    final createdAt = DateTime.now();
    return const <({String id, String label, String emoji})>[
      (id: 'important', label: 'Important', emoji: ''),
      (id: 'review', label: 'To Review', emoji: ''),
      (id: 'inspiration', label: 'Inspiration', emoji: ''),
      (id: 'goals', label: 'Goals', emoji: ''),
      (id: 'finance', label: 'Finance', emoji: ''),
      (id: 'health', label: 'Health', emoji: ''),
    ].map((tag) {
      return TagModel(
        id: tag.id,
        label: tag.label,
        createdAt: createdAt,
        updatedAt: createdAt,
        emoji: tag.emoji,
      );
    }).toList(growable: false);
  }
}
