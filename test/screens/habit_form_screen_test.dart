import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/screens/habit_form_screen.dart';
import 'package:habit_stack/services/habit_storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_stack_form_');
    HabitStorageService.resetForTesting(testDir: tempDir);
  });

  tearDown(() async {
    HabitStorageService.resetForTesting();
    await tempDir.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Habit habit({String id = 'h1', bool archived = false}) => Habit(
    id: id,
    behavior: 'wake up',
    time: '06:00',
    location: 'bedroom',
    createdAt: DateTime(2026, 1, 1),
    archived: archived,
  );

  /// The screen under a forced 24-hour locale.
  ///
  /// Without this the time picker opens in 12-hour mode, where the AM/PM
  /// toggle defaults to the period of the *current wall-clock time*. Typing
  /// "07" then yields 07:00 before noon but 19:00 after it, so these tests
  /// passed every morning and failed every afternoon. Pinning the format
  /// removes the ambiguity instead of guessing at the toggle.
  Widget app() => const MediaQuery(
    data: MediaQueryData(alwaysUse24HourFormat: true),
    child: MaterialApp(home: HabitFormScreen()),
  );

  /// Sets the time via the dialog's keyboard-entry mode (more robust in a
  /// widget test than dragging the analog dial).
  ///
  /// Scoped to [Dialog] descendants: the dialog's hour/minute
  /// [TextFormField]s each build an internal [TextField], which would
  /// otherwise collide by index with the form screen's own Behavior/
  /// Location [TextField]s still mounted behind the dialog.
  Future<void> pickTime(WidgetTester tester, String hour, String minute) async {
    await tester.tap(find.text('At...'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await settle(tester);
    final dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), hour);
    await tester.enterText(dialogFields.at(1), minute);
    await tester.tap(find.text('OK'));
    await settle(tester);
  }

  testWidgets(
    'typing a behavior live-renders the implementation-intention sentence',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          app(),
        );
        await settle(tester);

        expect(find.text('I will … at --:-- in …'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Behavior'),
          'meditate',
        );
        await settle(tester);

        expect(find.text('I will meditate at --:-- in …'), findsOneWidget);
      });
    },
  );

  testWidgets('filling all three fields renders the full sentence', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Behavior'),
        'meditate',
      );
      await settle(tester);
      await pickTime(tester, '07', '00');
      await tester.enterText(
        find.widgetWithText(TextField, 'Location'),
        'bedroom',
      );
      await settle(tester);

      expect(
        find.text('I will meditate at 07:00 in bedroom'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'Save habit is disabled until behavior + time + location are set',
    (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(app());
        await settle(tester);

        Widget button() =>
            tester.widget(find.widgetWithText(FilledButton, 'Save habit'));
        expect((button() as FilledButton).onPressed, isNull);

        await tester.enterText(
          find.widgetWithText(TextField, 'Behavior'),
          'meditate',
        );
        await settle(tester);
        expect((button() as FilledButton).onPressed, isNull);

        await pickTime(tester, '07', '00');
        expect((button() as FilledButton).onPressed, isNull);

        await tester.enterText(
          find.widgetWithText(TextField, 'Location'),
          'bedroom',
        );
        await settle(tester);
        expect((button() as FilledButton).onPressed, isNotNull);
      });
    },
  );

  testWidgets('choosing an anchor hides time/location and enables save', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit());
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Behavior'),
        'stretch',
      );
      await settle(tester);
      await tester.tap(find.text('None -- use time + location instead'));
      await settle(tester);
      await tester.tap(find.text('wake up').last);
      await settle(tester);

      expect(find.widgetWithText(TextField, 'Location'), findsNothing);
      expect(find.text('After wake up, I will stretch'), findsOneWidget);

      final button =
          tester.widget(find.widgetWithText(FilledButton, 'Save habit'))
              as FilledButton;
      expect(button.onPressed, isNotNull);
    });
  });

  testWidgets('the anchor picker excludes archived habits', (tester) async {
    await tester.runAsync(() async {
      await HabitStorageService.instance.addHabit(habit(id: 'h1'));
      await HabitStorageService.instance.addHabit(
        habit(id: 'h2', archived: true),
      );
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.tap(find.text('None -- use time + location instead'));
      await settle(tester);

      // Only the one non-archived habit's behavior appears as a candidate
      // (plus the "None" option, already matched above).
      expect(find.text('wake up'), findsOneWidget);
    });
  });

  testWidgets('saving persists the habit and pops the screen', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Same 24-hour pin as app(); this test needs its own navigator host so
      // it can assert the screen pops, but the picker is just as ambiguous.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const HabitFormScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Behavior'),
        'meditate',
      );
      await settle(tester);
      await pickTime(tester, '07', '00');
      await tester.enterText(
        find.widgetWithText(TextField, 'Location'),
        'bedroom',
      );
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save habit'));
      await settle(tester);

      expect(find.byType(HabitFormScreen), findsNothing);
      final habits = await HabitStorageService.instance.readHabits();
      expect(habits.single.behavior, 'meditate');
      expect(habits.single.time, '07:00');
      expect(habits.single.location, 'bedroom');
    });
  });
}
