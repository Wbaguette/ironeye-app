import 'package:intl/intl.dart';

class DateUtils {
  
  /// Converts a DateTime to RFC3339 format for API calls
  static String toRFC3339(DateTime dateTime) {
    // Format with local timezone and microseconds
    // Example: 2025-10-07T21:00:10.003178-04:00
    final String year = dateTime.year.toString().padLeft(4, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String second = dateTime.second.toString().padLeft(2, '0');
    final String microsecond = dateTime.microsecond.toString().padLeft(6, '0');
    
    // Get timezone offset
    final Duration offset = dateTime.timeZoneOffset;
    final String offsetSign = offset.isNegative ? '-' : '+';
    final int offsetHours = offset.inHours.abs();
    final int offsetMinutes = (offset.inMinutes.abs() % 60);
    final String offsetString = '$offsetSign${offsetHours.toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';
    
    return '$year-$month-${day}T$hour:$minute:$second.$microsecond$offsetString';
  }
  
  /// Parses an RFC3339 string to DateTime
  static DateTime fromRFC3339(String rfc3339String) {
    return DateTime.parse(rfc3339String);
  }
  
  /// Formats a DateTime for display in the UI
  static String formatDisplayDate(DateTime dateTime) {
    return DateFormat('EEEE, MMMM d, y').format(dateTime);
  }
  
  /// Formats time for display (e.g., "2:30 PM")
  static String formatDisplayTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
  
  /// Formats a date range for display
  static String formatDateRange(DateTime start, DateTime end) {
    final startStr = formatDisplayTime(start);
    final endStr = formatDisplayTime(end);
    return '$startStr - $endStr';
  }
  
  /// Returns a human-readable relative date (e.g., "Today", "Yesterday", "3 days ago")
  static String getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(dateOnly).inDays;
    
    switch (difference) {
      case 0:
        return 'Today';
      case 1:
        return 'Yesterday';
      case -1:
        return 'Tomorrow';
      default:
        if (difference > 0) {
          return '$difference days ago';
        } else {
          return 'In ${-difference} days';
        }
    }
  }
  
  /// Gets the start of a day (00:00:00)
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  /// Gets the end of a day (23:59:59.999)
  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }
  
  /// Checks if a date is within the last 7 days (for recording availability)
  static bool isWithinRecordingWindow(DateTime date) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return date.isAfter(sevenDaysAgo) && date.isBefore(now.add(const Duration(days: 1)));
  }
}