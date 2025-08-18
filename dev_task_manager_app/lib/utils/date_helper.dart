import 'package:intl/intl.dart';

class DateHelper {
  static final DateFormat _displayFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _apiFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _fullFormat = DateFormat('MMM dd, yyyy HH:mm');

  /// Format date for display (e.g., "Jan 15, 2024")
  static String formatForDisplay(DateTime date) {
    return _displayFormat.format(date);
  }

  /// Format date for API (e.g., "2024-01-15")
  static String formatForApi(DateTime date) {
    return _apiFormat.format(date);
  }

  /// Format time (e.g., "14:30")
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Format full date and time (e.g., "Jan 15, 2024 14:30")
  static String formatFull(DateTime date) {
    return _fullFormat.format(date);
  }

  /// Parse API date string to DateTime
  static DateTime? parseApiDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if a date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// Check if a date is overdue
  static bool isOverdue(DateTime dueDate) {
    final now = DateTime.now();
    return dueDate.isBefore(now) && !isToday(dueDate);
  }

  /// Get relative date string (e.g., "Today", "Tomorrow", "2 days ago")
  static String getRelativeDateString(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (isToday(date)) {
      return 'Today';
    } else if (isTomorrow(date)) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 0) {
      return 'In $difference days';
    } else {
      return '${difference.abs()} days ago';
    }
  }
}
