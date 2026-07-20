import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';

void main() {
  final createdAt = DateTime(2026, 1, 1);

  Habit make({
    String id = 'h1',
    String behavior = 'meditate',
    String time = '07:00',
    String location = 'bedroom',
    String? anchorHabitId,
  }) => Habit(
    id: id,
    behavior: behavior,
    time: time,
    location: location,
    createdAt: createdAt,
    anchorHabitId: anchorHabitId,
  );

  group('Habit', () {
    test('toJson/fromJson round-trips a standalone habit', () {
      final habit = make();
      final restored = Habit.fromJson(habit.toJson());
      expect(restored, habit);
    });

    test('toJson/fromJson round-trips an anchored, archived habit', () {
      final habit = make(anchorHabitId: 'anchor-1').copyWithArchived();
      final restored = Habit.fromJson(habit.toJson());
      expect(restored, habit);
      expect(restored.archived, isTrue);
      expect(restored.anchorHabitId, 'anchor-1');
    });

    test('fromJson defaults archived to false when absent', () {
      final json = make().toJson()..remove('archived');
      expect(Habit.fromJson(json).archived, isFalse);
    });

    test('copyWithArchived preserves every other field', () {
      final habit = make(anchorHabitId: 'a1');
      final archived = habit.copyWithArchived();
      expect(archived.id, habit.id);
      expect(archived.behavior, habit.behavior);
      expect(archived.time, habit.time);
      expect(archived.location, habit.location);
      expect(archived.createdAt, habit.createdAt);
      expect(archived.anchorHabitId, habit.anchorHabitId);
      expect(archived.archived, isTrue);
    });

    test('equality and hashCode are field-based', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(), isNot(make(behavior: 'other')));
    });

    test('toString includes the key fields', () {
      expect(make().toString(), contains('meditate'));
    });
  });

  group('renderSentence', () {
    test('standalone habit renders "I will X at T in L"', () {
      expect(
        renderSentence(make()),
        'I will meditate at 07:00 in bedroom',
      );
    });

    test('anchored habit renders "After Y, I will X" instead', () {
      final anchor = make(id: 'a1', behavior: 'wake up');
      final stacked = make(id: 'h2', anchorHabitId: 'a1');
      expect(
        renderSentence(stacked, anchor: anchor),
        'After wake up, I will meditate',
      );
    });
  });

  group('wouldCreateCycle', () {
    test('a habit anchoring to itself is a cycle', () {
      expect(wouldCreateCycle('h1', 'h1', [make()]), isTrue);
    });

    test('a direct A->B->A cycle is detected', () {
      final a = make(id: 'a', anchorHabitId: 'b');
      final b = make(id: 'b', anchorHabitId: null);
      // Proposing to set b's anchor to a, when a already anchors to b.
      expect(wouldCreateCycle('a', 'b', [a, b]), isTrue);
    });

    test('a longer chain cycle is detected', () {
      final a = make(id: 'a', anchorHabitId: 'b');
      final b = make(id: 'b', anchorHabitId: 'c');
      final c = make(id: 'c');
      // Proposing to set c's anchor to a, closing a->b->c->a.
      expect(wouldCreateCycle('a', 'c', [a, b, c]), isTrue);
    });

    test('a non-cyclic chain is not a cycle', () {
      final a = make(id: 'a');
      final b = make(id: 'b', anchorHabitId: 'a');
      expect(wouldCreateCycle('a', 'c', [a, b]), isFalse);
    });

    test('unrelated habits never create a cycle', () {
      final a = make(id: 'a');
      final b = make(id: 'b');
      expect(wouldCreateCycle('a', 'b', [a, b]), isFalse);
    });

    test(
      'a pre-existing unrelated cycle in the data does not false-positive',
      () {
        final a = make(id: 'a', anchorHabitId: 'b');
        final b = make(id: 'b', anchorHabitId: 'a');
        // c is unrelated to the a<->b loop; walking into it must terminate.
        expect(wouldCreateCycle('a', 'c', [a, b]), isFalse);
      },
    );
  });
}
