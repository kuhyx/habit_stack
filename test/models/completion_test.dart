import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/completion.dart';

void main() {
  group('Completion', () {
    test('toJson/fromJson round-trips', () {
      const completion = Completion(habitId: 'h1', date: '2026-06-22');
      final restored = Completion.fromJson(completion.toJson());
      expect(restored, completion);
    });

    test('equality and hashCode are field-based', () {
      const a = Completion(habitId: 'h1', date: '2026-06-22');
      const b = Completion(habitId: 'h1', date: '2026-06-22');
      const c = Completion(habitId: 'h2', date: '2026-06-22');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString includes habitId and date', () {
      const completion = Completion(habitId: 'h1', date: '2026-06-22');
      expect(completion.toString(), contains('h1'));
      expect(completion.toString(), contains('2026-06-22'));
    });
  });
}
