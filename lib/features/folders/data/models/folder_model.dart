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
    return _systemFolderDescriptors.map((folder) {
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

  static bool isSystemId(String? id) {
    final normalizedId = id?.trim().toLowerCase();
    if (normalizedId == null || normalizedId.isEmpty) {
      return false;
    }

    return _systemFolderIds.contains(normalizedId);
  }

  static String? inferSystemFolderId({
    String? folderId,
    String? colorKey,
    String? name,
  }) {
    final normalizedFolderId = folderId?.trim();
    if (normalizedFolderId != null && normalizedFolderId.isNotEmpty) {
      return normalizedFolderId;
    }

    final normalizedName = name?.trim().toLowerCase();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      for (final folder in _systemFolderDescriptors) {
        if (folder.name.toLowerCase() == normalizedName) {
          return folder.id;
        }
      }

      return null;
    }

    final normalizedColorKey = colorKey?.trim().toLowerCase();
    if (normalizedColorKey != null &&
        _systemFolderIds.contains(normalizedColorKey)) {
      return normalizedColorKey;
    }

    return null;
  }
}

const List<({String id, String name, String colorKey, String emoji})>
    _systemFolderDescriptors = <({
  String id,
  String name,
  String colorKey,
  String emoji,
})>[
  (id: 'personal', name: 'Personal', colorKey: 'personal', emoji: '💖'),
  (id: 'study', name: 'Study', colorKey: 'study', emoji: '📚'),
  (id: 'ideas', name: 'Ideas', colorKey: 'ideas', emoji: '💡'),
  (id: 'work', name: 'Work', colorKey: 'work', emoji: '💼'),
  (id: 'journal', name: 'Journal', colorKey: 'journal', emoji: '✍️'),
];

final Set<String> _systemFolderIds =
    _systemFolderDescriptors.map((folder) => folder.id).toSet();
