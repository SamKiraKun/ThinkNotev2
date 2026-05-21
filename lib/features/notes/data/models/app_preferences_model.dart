import 'package:flutter/material.dart';

enum NoteSortOrder {
  updatedDesc,
  createdDesc,
  titleAsc,
}

enum AppThemePreference {
  system,
  light,
  dark,
}

extension NoteSortOrderX on NoteSortOrder {
  String get storageValue {
    switch (this) {
      case NoteSortOrder.updatedDesc:
        return 'updated_desc';
      case NoteSortOrder.createdDesc:
        return 'created_desc';
      case NoteSortOrder.titleAsc:
        return 'title_asc';
    }
  }

  String get label {
    switch (this) {
      case NoteSortOrder.updatedDesc:
        return 'Last updated';
      case NoteSortOrder.createdDesc:
        return 'Created date';
      case NoteSortOrder.titleAsc:
        return 'Title A-Z';
    }
  }

  static NoteSortOrder fromStorage(String? value) {
    switch (value) {
      case 'created_desc':
        return NoteSortOrder.createdDesc;
      case 'title_asc':
        return NoteSortOrder.titleAsc;
      case 'updated_desc':
      default:
        return NoteSortOrder.updatedDesc;
    }
  }
}

extension AppThemePreferenceX on AppThemePreference {
  String get storageValue {
    switch (this) {
      case AppThemePreference.system:
        return 'system';
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
    }
  }

  String get label {
    switch (this) {
      case AppThemePreference.system:
        return 'System';
      case AppThemePreference.light:
        return 'Light';
      case AppThemePreference.dark:
        return 'Dark';
    }
  }

  ThemeMode get themeMode {
    switch (this) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  static AppThemePreference fromStorage(String? value) {
    switch (value) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      case 'system':
      default:
        return AppThemePreference.system;
    }
  }
}

class AppPreferencesModel {
  const AppPreferencesModel({
    this.defaultSortOrder = NoteSortOrder.updatedDesc,
    this.previewLines = 2,
    this.themePreference = AppThemePreference.system,
  });

  final NoteSortOrder defaultSortOrder;
  final int previewLines;
  final AppThemePreference themePreference;

  factory AppPreferencesModel.fromJson(Map<String, dynamic>? json) {
    return AppPreferencesModel(
      defaultSortOrder: NoteSortOrderX.fromStorage(
        json?['default_sort_order'] as String?,
      ),
      previewLines: (json?['preview_lines'] as int?)?.clamp(1, 4) ?? 2,
      themePreference: AppThemePreferenceX.fromStorage(
        json?['theme_preference'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'default_sort_order': defaultSortOrder.storageValue,
      'preview_lines': previewLines,
      'theme_preference': themePreference.storageValue,
    };
  }

  AppPreferencesModel copyWith({
    NoteSortOrder? defaultSortOrder,
    int? previewLines,
    AppThemePreference? themePreference,
  }) {
    return AppPreferencesModel(
      defaultSortOrder: defaultSortOrder ?? this.defaultSortOrder,
      previewLines: previewLines ?? this.previewLines,
      themePreference: themePreference ?? this.themePreference,
    );
  }
}
