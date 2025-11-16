class DateUtils {
  static String toRFC3339Local(DateTime dateTime) {
    final String year = dateTime.year.toString().padLeft(4, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String second = dateTime.second.toString().padLeft(2, '0');

    // Get timezone offset
    final Duration offset = dateTime.timeZoneOffset;
    final String offsetSign = offset.isNegative ? '-' : '+';
    final int offsetHours = offset.inHours.abs();
    final int offsetMinutes = (offset.inMinutes.abs() % 60);
    final String offsetString =
        '$offsetSign${offsetHours.toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';

    return '$year-$month-${day}T$hour:$minute:$second$offsetString';
  }

  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }
}
