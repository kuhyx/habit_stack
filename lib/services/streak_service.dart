/// Pure streak-calculation logic, backing the "don't break the chain" view.
library;

import 'package:habit_stack/models/local_date.dart';

/// Returns the current consecutive-day streak ending at [asOf] (default
/// now), given the set of local date keys (`YYYY-MM-DD`) a habit was
/// completed on.
///
/// Habits are implicitly daily (see `habit.dart`), so the break rule is
/// simply "the previous day's date key is missing from the set". Today not
/// yet being marked does NOT break the streak by itself -- it only breaks
/// once a full day has passed with no completion, so the streak counts back
/// from the most recent completed day (today or yesterday) rather than
/// requiring today specifically to already be done.
int currentStreak(Set<String> completionDates, {DateTime? asOf}) {
  final today = asOf ?? DateTime.now();
  var cursor = today;
  if (!completionDates.contains(localDateKey(cursor))) {
    // Today isn't done yet -- start counting from yesterday instead, so a
    // habit already completed every day up to and including yesterday
    // still shows a live streak until today's window closes.
    cursor = cursor.subtract(const Duration(days: 1));
    if (!completionDates.contains(localDateKey(cursor))) return 0;
  }
  var streak = 0;
  while (completionDates.contains(localDateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
