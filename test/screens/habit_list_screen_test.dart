import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/screens/habit_form_screen.dart';
import 'package:habit_stack/screens/habit_list_screen.dart';
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

  // initState fires real dart:io reads as fire-and-forget Futures the frame
  // scheduler doesn't track; run under runAsync with a short real delay
  // before pumpAndSettle, mirroring diet_guard's LogMealScreen test pattern.
  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Habit habit({String id = 'h1', String? anchorHabitId}) => Habit(
    id: id,
    behavior: 'meditate',
    time: '07:00',
    location: 'bedroom',
    createdAt: DateTime(2026, 1, 1),
    anchorHabitId: anchorHabitId,
  );

  testWidgets('shows an empty-state message with no habits', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: HabitListScreen(key: UniqueKey())),
      );
      await settle(tester);

      expect(find.text('No habits yet -- add one below.'), findsOneWidget);
    });
  });

  testWidgets('lists a habit\'s rendered sentence', (tester) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit());
      await tester.pumpWidget(const MaterialApp(home: HabitListScreen()));
      await settle(tester);

      expect(
        find.text('I will meditate at 07:00 in bedroom'),
        findsOneWidget,
      );
    });
  });

  testWidgets('an anchored habit renders the stacked sentence via the anchor', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(
        habit(id: 'a1'),
      ); // anchor: "meditate"
      await HabitStorageService.instance.addHabit(
        habit(id: 'h2', anchorHabitId: 'a1'),
      );
      await tester.pumpWidget(const MaterialApp(home: HabitListScreen()));
      await settle(tester);

      expect(find.text('After meditate, I will meditate'), findsOneWidget);
    });
  });

  testWidgets('archived habits are not listed', (tester) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(
        habit().copyWithArchived(),
      );
      await tester.pumpWidget(const MaterialApp(home: HabitListScreen()));
      await settle(tester);

      expect(find.text('No habits yet -- add one below.'), findsOneWidget);
    });
  });

  testWidgets('tapping a row toggles today\'s completion, icon updates', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit());
      await tester.pumpWidget(const MaterialApp(home: HabitListScreen()));
      await settle(tester);

      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

      await tester.tap(find.byType(ListTile));
      await settle(tester);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  testWidgets('tapping a done row again un-marks it', (tester) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit());
      await tester.pumpWidget(const MaterialApp(home: HabitListScreen()));
      await settle(tester);

      await tester.tap(find.byType(ListTile));
      await settle(tester);
      await tester.tap(find.byType(ListTile));
      await settle(tester);

      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });
  });

  testWidgets('the FAB navigates to HabitFormScreen and back refreshes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: HabitListScreen()));
      await settle(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'New habit'));
      await settle(tester);
      expect(find.byType(HabitFormScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.byType(HabitListScreen), findsOneWidget);
    });
  });

  testWidgets('the streaks icon navigates to StreakScreen', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: HabitListScreen()));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.local_fire_department));
      await settle(tester);

      expect(find.byType(StreakScreen), findsOneWidget);
    });
  });
}
