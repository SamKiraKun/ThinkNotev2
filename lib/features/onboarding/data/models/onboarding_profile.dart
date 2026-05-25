import 'package:flutter/material.dart';

import '../../../notes/data/models/app_preferences_model.dart';

enum WorkspaceFocus {
  capture,
  planning,
  research,
  journal,
}

extension WorkspaceFocusX on WorkspaceFocus {
  String get storageValue {
    switch (this) {
      case WorkspaceFocus.capture:
        return 'capture';
      case WorkspaceFocus.planning:
        return 'planning';
      case WorkspaceFocus.research:
        return 'research';
      case WorkspaceFocus.journal:
        return 'journal';
    }
  }

  String get label {
    switch (this) {
      case WorkspaceFocus.capture:
        return 'Idea capture';
      case WorkspaceFocus.planning:
        return 'Team planning';
      case WorkspaceFocus.research:
        return 'Research';
      case WorkspaceFocus.journal:
        return 'Daily journal';
    }
  }

  String get headline {
    switch (this) {
      case WorkspaceFocus.capture:
        return 'Capture ideas before they disappear';
      case WorkspaceFocus.planning:
        return 'Keep projects and meetings in one system';
      case WorkspaceFocus.research:
        return 'Collect sources, highlights, and summaries';
      case WorkspaceFocus.journal:
        return 'Build a calm daily writing ritual';
    }
  }

  String get description {
    switch (this) {
      case WorkspaceFocus.capture:
        return 'Fast entry, recent activity, and pinned notes stay front and center.';
      case WorkspaceFocus.planning:
        return 'Folders, collections, and status views are optimized for active work.';
      case WorkspaceFocus.research:
        return 'Search, tags, and structured collections become the primary workflow.';
      case WorkspaceFocus.journal:
        return 'A focused, distraction-light layout keeps daily reflection easy to revisit.';
    }
  }

  String get dashboardMessage {
    switch (this) {
      case WorkspaceFocus.capture:
        return 'Keep ideas moving from quick capture into organized notes.';
      case WorkspaceFocus.planning:
        return 'Track active work, decisions, and reference notes in one workspace.';
      case WorkspaceFocus.research:
        return 'Surface your strongest source material and revisit it quickly.';
      case WorkspaceFocus.journal:
        return 'Create space for recent reflections and the next writing session.';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkspaceFocus.capture:
        return Icons.bolt_rounded;
      case WorkspaceFocus.planning:
        return Icons.space_dashboard_rounded;
      case WorkspaceFocus.research:
        return Icons.manage_search_rounded;
      case WorkspaceFocus.journal:
        return Icons.auto_stories_rounded;
    }
  }

  static WorkspaceFocus fromStorage(String? value) {
    switch (value) {
      case 'planning':
        return WorkspaceFocus.planning;
      case 'research':
        return WorkspaceFocus.research;
      case 'journal':
        return WorkspaceFocus.journal;
      case 'capture':
      default:
        return WorkspaceFocus.capture;
    }
  }
}

class OnboardingProfile {
  const OnboardingProfile({
    required this.hasCompletedOnboarding,
    required this.workspaceName,
    required this.workspaceFocus,
    required this.wantsNotifications,
    required this.themePreference,
  });

  final bool hasCompletedOnboarding;
  final String workspaceName;
  final WorkspaceFocus workspaceFocus;
  final bool wantsNotifications;
  final AppThemePreference themePreference;

  factory OnboardingProfile.initial() {
    return const OnboardingProfile(
      hasCompletedOnboarding: false,
      workspaceName: '',
      workspaceFocus: WorkspaceFocus.capture,
      wantsNotifications: false,
      themePreference: AppThemePreference.system,
    );
  }

  String get effectiveWorkspaceName {
    final normalized = workspaceName.trim();
    if (normalized.isEmpty) {
      return 'My Workspace';
    }
    return normalized;
  }

  String get initials {
    final parts = effectiveWorkspaceName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'W';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  OnboardingProfile copyWith({
    bool? hasCompletedOnboarding,
    String? workspaceName,
    WorkspaceFocus? workspaceFocus,
    bool? wantsNotifications,
    AppThemePreference? themePreference,
  }) {
    return OnboardingProfile(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      workspaceName: workspaceName ?? this.workspaceName,
      workspaceFocus: workspaceFocus ?? this.workspaceFocus,
      wantsNotifications: wantsNotifications ?? this.wantsNotifications,
      themePreference: themePreference ?? this.themePreference,
    );
  }
}