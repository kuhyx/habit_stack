import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/models/local_date.dart';
import 'package:habit_stack/screens/streak_screen.dart';
import 'package:habit_stack/services/document_store.dart';
import 'package:habit_stack/services/habit_storage_service.dart';

void main() {

  setUp(() async {
    HabitStorageService.resetForTesting(store: InMemoryDocumentStore());
  });

  tearDown(() async {
    HabitStorageService.resetForTesting();
  });

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Habit habit({String id = 'h1'}) => Habit(
    id: id,
    behavior: 'meditate',
    time: '07:00',
    location: 'bedroom',
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets('shows an empty-state message with no habits', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: StreakScreen()));
      await settle(tester);

      expect(find.text('No habits yet.'), findsOneWidget);
    });
  });

  testWidgets('shows a zero streak for a habit never completed', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit());
      await tester.pumpWidget(const MaterialApp(home: StreakScreen()));
      await settle(tester);

      expect(find.text('meditate'), findsOneWidget);
      expect(find.text('Streak: 0 days'), findsOneWidget);
    });
  });

  testWidgets('shows the correct streak count from fixture completions', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit());
      final today = DateTime.now();
      await HabitStorageService.instance.toggleCompletion(
        'h1',
        localDateKey(today),
      );
      await HabitStorageService.instance.toggleCompletion(
        'h1',
        localDateKey(today.subtract(const Duration(days: 1))),
      );
      await tester.pumpWidget(const MaterialApp(home: StreakScreen()));
      await settle(tester);

      expect(find.text('Streak: 2 days'), findsOneWidget);
    });
  });

  testWidgets('a one-day streak uses singular "day"', (tester) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit());
      await HabitStorageService.instance.toggleCompletion(
        'h1',
        localDateKey(DateTime.now()),
      );
      await tester.pumpWidget(const MaterialApp(home: StreakScreen()));
      await settle(tester);

      expect(find.text('Streak: 1 day'), findsOneWidget);
    });
  });

  testWidgets('archived habits are not listed', (tester) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(
        habit().copyWithArchived(),
      );
      await tester.pumpWidget(const MaterialApp(home: StreakScreen()));
      await settle(tester);

      expect(find.text('No habits yet.'), findsOneWidget);
    });
  });
}
