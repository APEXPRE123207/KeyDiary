import 'package:intl/intl.dart';

/// Formatter for human-readable dates in vault records and activity timestamps
class DateFormatter {
  DateFormatter._();

  static final DateFormat _recordDate = DateFormat('dd MMM yyyy');
  static final DateFormat _timeOnly = DateFormat('h:mm a');

  static String formatRecordDate(DateTime date) {
    return _recordDate.format(date);
  }

  static String formatRelativeTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays == 0 && now.day == timestamp.day) {
      return 'Today at ${_timeOnly.format(timestamp)}';
    } else if (diff.inDays <= 1) {
      return 'Yesterday at ${_timeOnly.format(timestamp)}';
    } else {
      return _recordDate.format(timestamp);
    }
  }
}
