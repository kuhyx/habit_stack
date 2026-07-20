/// Local calendar-date formatting, mirroring diet_guard's `local_time.dart`.
library;

/// Returns [now]'s local calendar date as `YYYY-MM-DD`.
///
/// Local, not UTC: a habit completed late in the evening must not roll
/// into tomorrow's date key.
String localDateKey(DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year.toString().padLeft(4, '0')}-'
      '${two(now.month)}-${two(now.day)}';
}
