import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/local_date.dart';
import 'package:habit_stack/services/streak_service.dart';

void main() {
  final today = DateTime(2026, 6, 22);

  String daysAgo(int n) => localDateKey(today.subtract(Duration(days: n)));

  group('currentStreak', () {
    test('no completions is a zero streak', () {
      expect(currentStreak({}, asOf: today), 0);
    });

    test('a consecutive run ending today counts every day', () {
      final dates = {daysAgo(0), daysAgo(1), daysAgo(2)};
      expect(currentStreak(dates, asOf: today), 3);
    });

    test('one gap breaks the streak', () {
      final dates = {daysAgo(0), daysAgo(2)}; // yesterday missing
      expect(currentStreak(dates, asOf: today), 1);
    });

    test(
      'today not yet marked does not break a streak through yesterday',
      () {
        final dates = {daysAgo(1), daysAgo(2), daysAgo(3)};
        expect(currentStreak(dates, asOf: today), 3);
      },
    );

    test('neither today nor yesterday done is a zero streak', () {
      final dates = {daysAgo(2), daysAgo(3)};
      expect(currentStreak(dates, asOf: today), 0);
    });

    test('defaults asOf to DateTime.now() when omitted', () {
      // Just confirm it runs without a fixed clock and returns a valid int.
      expect(currentStreak({}), 0);
    });
  });
}
