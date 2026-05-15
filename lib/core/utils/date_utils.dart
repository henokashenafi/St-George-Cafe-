import 'package:ethiopian_datetime/ethiopian_datetime.dart';

class PosDateUtils {
  /// Returns a formatted Ethiopian date string for the given Gregorian date.
  /// Format: Month day, year (e.g., መስከረም 1, 2017)
  static String formatEthiopianDate(DateTime date) {
    final etDate = ETDateTime.now();
    // MMMM d, yyyy gives localized Month, Day, Year
    return ETDateFormat("MMMM d, yyyy").format(etDate);
  }

  /// Returns a formatted Ethiopian date and time string.
  static String formatEthiopianDateTime(DateTime date) {
    final etDate = ETDateTime.now();
    final datePart = ETDateFormat("MMMM d, yyyy").format(etDate);
    final timePart = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    return "$datePart $timePart";
  }
}
