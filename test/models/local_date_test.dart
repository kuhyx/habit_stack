import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/local_date.dart';

void main() {
  group('localDateKey', () {
    test('formats a date as YYYY-MM-DD, zero-padded', () {
      expect(localDateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('does not roll over based on time-of-day', () {
      expect(localDateKey(DateTime(2026, 6, 22, 23, 59)), '2026-06-22');
    });
  });
}
