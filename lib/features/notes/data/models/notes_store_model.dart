import '../../../folders/data/models/folder_model.dart';
import '../../../folders/data/models/tag_model.dart';
import 'app_preferences_model.dart';
import 'note_model.dart';

class NotesStoreModel {
  const NotesStoreModel({
    required this.notes,
    required this.folders,
    required this.tags,
    required this.recentSearches,
    required this.preferences,
  });

  final List<NoteModel> notes;
  final List<FolderModel> folders;
  final List<TagModel> tags;
  final List<String> recentSearches;
  final AppPreferencesModel preferences;

  factory NotesStoreModel.empty() {
    return NotesStoreModel(
      notes: const <NoteModel>[],
      folders: FolderModel.defaults(),
      tags: TagModel.defaults(),
      recentSearches: const <String>[],
      preferences: const AppPreferencesModel(),
    );
  }

  factory NotesStoreModel.fromJson(Map<String, dynamic> json) {
    return NotesStoreModel(
      notes: (json['notes'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(NoteModel.fromJson)
          .toList(growable: false),
      folders: (json['folders'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FolderModel.fromJson)
          .toList(growable: false),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TagModel.fromJson)
          .toList(growable: false),
      recentSearches:
          (json['recent_searches'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .toList(growable: false),
      preferences: AppPreferencesModel.fromJson(
        json['preferences'] as Map<String, dynamic>?,
      ),
    ).withDefaults();
  }

  NotesStoreModel withDefaults() {
    return copyWith(
      folders: folders.isEmpty ? FolderModel.defaults() : folders,
      tags: tags.isEmpty ? TagModel.defaults() : tags,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notes': notes.map((note) => note.toJson()).toList(growable: false),
      'folders':
          folders.map((folder) => folder.toJson()).toList(growable: false),
      'tags': tags.map((tag) => tag.toJson()).toList(growable: false),
      'recent_searches': recentSearches,
      'preferences': preferences.toJson(),
    };
  }

  NotesStoreModel copyWith({
    List<NoteModel>? notes,
    List<FolderModel>? folders,
    List<TagModel>? tags,
    List<String>? recentSearches,
    AppPreferencesModel? preferences,
  }) {
    return NotesStoreModel(
      notes: notes ?? this.notes,
      folders: folders ?? this.folders,
      tags: tags ?? this.tags,
      recentSearches: recentSearches ?? this.recentSearches,
      preferences: preferences ?? this.preferences,
    );
  }
}
