import '../../domain/entities/folder_entity.dart';

class FolderModel extends FolderEntity {
  const FolderModel({
    required super.id,
    required super.name,
    required super.colorKey,
    required super.emoji,
    required super.createdAt,
    required super.updatedAt,
    super.isSystem,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      colorKey: json['color_key'] as String? ?? 'personal',
      emoji: json['emoji'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.parse(json['updated_at'] as String),
      isSystem: json['is_system'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'color_key': colorKey,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_system': isSystem,
    };
  }

  FolderModel copyWith({
    String? name,
    String? colorKey,
    String? emoji,
    DateTime? updatedAt,
    bool? isSystem,
  }) {
    return FolderModel(
      id: id,
      name: name ?? this.name,
      colorKey: colorKey ?? this.colorKey,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  static List<FolderModel> defaults() {
    final createdAt = DateTime.now();
    return const <({String id, String name, String colorKey, String emoji})>[
      (id: 'personal', name: 'Personal', colorKey: 'personal', emoji: '💜'),
      (id: 'study', name: 'Study', colorKey: 'study', emoji: '📚'),
      (id: 'ideas', name: 'Ideas', colorKey: 'ideas', emoji: '💡'),
      (id: 'work', name: 'Work', colorKey: 'work', emoji: '💼'),
      (id: 'journal', name: 'Journal', colorKey: 'journal', emoji: '✍️'),
    ].map((folder) {
      return FolderModel(
        id: folder.id,
        name: folder.name,
        colorKey: folder.colorKey,
        emoji: folder.emoji,
        createdAt: createdAt,
        updatedAt: createdAt,
        isSystem: true,
      );
    }).toList(growable: false);
  }
}
