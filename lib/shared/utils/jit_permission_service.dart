import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_jit_permission_dialog.dart';

class JitPermissionService {
  const JitPermissionService._();

  static const String _notificationsKey = 'permission_notifications';
  static const String _microphoneKey = 'permission_microphone';
  static const String _storageKey = 'permission_storage';

  /// Check if permission is already granted in SharedPreferences
  static Future<bool> hasPermission(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  /// Request a permission with a contextual primer explanation dialog
  static Future<bool> requestPermission(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String title,
    required String description,
  }) async {
    final alreadyGranted = await hasPermission(key);
    if (alreadyGranted) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    // Show pre-permission primer dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppJitPermissionDialog(
        icon: icon,
        title: title,
        description: description,
        permissionLabel: key,
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
      return true;
    }

    return false;
  }

  static Future<bool> requestNotifications(BuildContext context) {
    return requestPermission(
      context,
      key: _notificationsKey,
      icon: Icons.notifications_active_rounded,
      title: 'Enable Workspace Alerts?',
      description:
          'ThinkNote needs notification permissions to deliver timed reminders and calendar follow-ups for your journal logs.',
    );
  }

  static Future<bool> requestMicrophone(BuildContext context) {
    return requestPermission(
      context,
      key: _microphoneKey,
      icon: Icons.mic_none_rounded,
      title: 'Allow Microphone Access?',
      description:
          'To record quick voice logs, transcribe speech, or append voice memos, ThinkNote requires access to your microphone.',
    );
  }

  static Future<bool> requestStorage(BuildContext context) {
    return requestPermission(
      context,
      key: _storageKey,
      icon: Icons.photo_library_outlined,
      title: 'Allow Media & Storage?',
      description:
          'ThinkNote requires access to your photo library and files to allow attaching media assets, PDFs, and export/import note databases.',
    );
  }
}
