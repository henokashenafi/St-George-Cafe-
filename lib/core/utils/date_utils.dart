import 'package:ethiopian_datetime/ethiopian_datetime.dart';

class PosDateUtils {
  /// Returns a formatted Ethiopian date string for the given Gregorian date.
  /// Format: Month day, year (e.g., መስከረም 1, 2017)
  static String formatEthiopianDate(DateTime date) {
    final etDate = date.convertToEthiopian();
    // Use standard digits instead of Ethiopic ones to avoid box rendering issues
    final monthName = ETDateFormat("MMMM").format(etDate);
    return "$monthName ${etDate.day}, ${etDate.year}";
  }

  /// Returns a formatted Ethiopian date and time string.
  static String formatEthiopianDateTime(DateTime date) {
    final etDate = date.convertToEthiopian();
    final monthName = ETDateFormat("MMMM").format(etDate);
    final datePart = "$monthName ${etDate.day}, ${etDate.year}";
    final timePart = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    return "$datePart $timePart";
  }
}
