import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _monthDayYear = DateFormat('MMM d, y');
  static final DateFormat _monthDayYearTime =
      DateFormat('MMM d, y \'at\' h:mm a');

  static String formatFullDate(DateTime value) {
    return _monthDayYear.format(value.toLocal());
  }

  static String formatDateTime(DateTime value) {
    return _monthDayYearTime.format(value.toLocal());
  }

  static String formatRelative(DateTime value, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final localValue = value.toLocal();
    final difference = current.difference(localValue);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return formatFullDate(localValue);
  }

  static String estimateReadTime(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '1 min read';
    }

    final words = trimmed.split(RegExp(r'\s+')).length;
    final minutes = (words / 180).ceil().clamp(1, 99);
    return '$minutes min read';
  }
}
