import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/screens/habit_form_screen.dart';
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

  Habit habit({String id = 'h1', bool archived = false}) => Habit(
    id: id,
    behavior: 'wake up',
    time: '06:00',
    location: 'bedroom',
    createdAt: DateTime(2026, 1, 1),
    archived: archived,
  );

  /// The screen alone. The time wheel is always 24-hour, so no locale pin
  /// is needed (Material's picker defaulted AM/PM to the wall clock).
  Widget app() => const MaterialApp(home: HabitFormScreen());

  /// Sets the time through the text-free wheel sheet: drives the wheel's
  /// callback directly (dragging wheels is brittle), then taps the check.
  Future<void> pickTime(WidgetTester tester, int hour, int minute) async {
    await tester.tap(find.byKey(const Key('timeButton')));
    await settle(tester);
    tester
        .widget<CupertinoDatePicker>(find.byKey(const Key('timeWheel')))
        .onDateTimeChanged(DateTime(2000, 1, 1, hour, minute));
    await tester.tap(find.byKey(const Key('timeConfirm')));
    await settle(tester);
  }

  Finder inPreview(String text) => find.descendant(
    of: find.byKey(const Key('preview')),
    matching: find.text(text),
  );

  testWidgets(
    'typing a behavior live-renders the implementation-intention sentence',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(app());
        await settle(tester);

        expect(
          find.descendant(
            of: find.byKey(const Key('preview')),
            matching: find.byType(Text),
          ),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const Key('behaviorField')),
          'meditate',
        );
        await settle(tester);

        expect(inPreview('meditate'), findsOneWidget);
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
        find.byKey(const Key('behaviorField')),
        'meditate',
      );
      await settle(tester);
      await pickTime(tester, 7, 0);
      await tester.enterText(find.byKey(const Key('locationField')), 'bedroom');
      await settle(tester);

      expect(inPreview('meditate'), findsOneWidget);
      expect(inPreview('07:00'), findsOneWidget);
      expect(inPreview('bedroom'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('I will meditate at 07:00 in bedroom'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  testWidgets(
    'Save habit is disabled until behavior + time + location are set',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(app());
        await settle(tester);

        Widget button() => tester.widget(find.byKey(const Key('saveButton')));
        expect((button() as FilledButton).onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('behaviorField')),
          'meditate',
        );
        await settle(tester);
        expect((button() as FilledButton).onPressed, isNull);

        await pickTime(tester, 7, 0);
        expect((button() as FilledButton).onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('locationField')),
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

      await tester.enterText(find.byKey(const Key('behaviorField')), 'stretch');
      await settle(tester);
      await tester.tap(find.byKey(const Key('anchorPicker')));
      await settle(tester);
      await tester.tap(find.text('wake up'));
      await settle(tester);

      expect(find.byKey(const Key('locationField')), findsNothing);
      expect(inPreview('wake up'), findsOneWidget);
      expect(inPreview('stretch'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('preview')),
          matching: find.byIcon(Icons.arrow_forward),
        ),
        findsOneWidget,
      );

      final button =
          tester.widget(find.byKey(const Key('saveButton'))) as FilledButton;
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

      await tester.tap(find.byKey(const Key('anchorPicker')));
      await settle(tester);

      // Only the one non-archived habit's behavior appears as a candidate
      // (plus the "None" option, already matched above).
      expect(find.text('wake up'), findsOneWidget);
    });
  });

  testWidgets('saving persists the habit and pops the screen', (tester) async {
    await tester.runAsync(() async {
      // Own navigator host so the test can assert the screen pops.
      await tester.pumpWidget(
        MaterialApp(
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
      );
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);

      await tester.enterText(
        find.byKey(const Key('behaviorField')),
        'meditate',
      );
      await settle(tester);
      await pickTime(tester, 7, 0);
      await tester.enterText(find.byKey(const Key('locationField')), 'bedroom');
      await settle(tester);

      await tester.tap(find.byKey(const Key('saveButton')));
      await settle(tester);

      expect(find.byType(HabitFormScreen), findsNothing);
      final habits = await HabitStorageService.instance.readHabits();
      expect(habits.single.behavior, 'meditate');
      expect(habits.single.time, '07:00');
      expect(habits.single.location, 'bedroom');
    });
  });
}
