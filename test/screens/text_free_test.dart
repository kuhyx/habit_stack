/// Textgate guard: no screen paints a word kuhy did not type.
///
/// Walks every painted [RichText] (a [Text] builds one; icons are private-use
/// codepoints and pass) and fails on any run of 2+ letters unless the whole
/// string is seeded user content (a behavior or location).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/screens/habit_form_screen.dart';
import 'package:habit_stack/screens/habit_list_screen.dart';
import 'package:habit_stack/screens/streak_screen.dart';
import 'package:habit_stack/services/document_store.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/ui/theme.dart';

/// Strings the user typed; the only words allowed on screen.
const Set<String> _content = {'meditate', 'bedroom', 'stretch'};

final RegExp _word = RegExp('[A-Za-z]{2,}');

/// Every painted string that holds a word and is not user content.
List<String> _chromeWords(WidgetTester tester) {
  final insideEditable = find
      .descendant(
        of: find.byType(EditableText),
        matching: find.byType(RichText),
      )
      .evaluate()
      .toSet();
  return [
    for (final element in find.byType(RichText).evaluate())
      if (!insideEditable.contains(element))
        (element.widget as RichText).text.toPlainText(),
  ].where((s) => _word.hasMatch(s) && !_content.contains(s.trim())).toList();
}

void main() {
  setUp(() {
    HabitStorageService.resetForTesting(store: InMemoryDocumentStore());
  });

  tearDown(HabitStorageService.resetForTesting);

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> seed() async {
    await HabitStorageService.instance.addHabit(
      Habit(
        id: 'a1',
        behavior: 'meditate',
        time: '07:00',
        location: 'bedroom',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await HabitStorageService.instance.addHabit(
      Habit(
        id: 'b1',
        behavior: 'stretch',
        time: '',
        location: '',
        createdAt: DateTime(2026, 1, 2),
        anchorHabitId: 'a1',
      ),
    );
  }

  Widget host(Widget home) => MaterialApp(theme: buildLightTheme(), home: home);

  testWidgets('list with habits and its archive sheet are word-free', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seed();
      await tester.pumpWidget(host(const HabitListScreen()));
      await settle(tester);
      expect(find.byType(RichText), findsWidgets);
      expect(_chromeWords(tester), isEmpty);
    });

    // Outside runAsync: its zone makes the long-press timer real time.
    await tester.longPress(find.text('stretch').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archiveTile')), findsOneWidget);
    expect(_chromeWords(tester), isEmpty);
  });

  testWidgets('streak screen with habits is word-free', (tester) async {
    await tester.runAsync(() async {
      await seed();
      await tester.pumpWidget(host(const StreakScreen()));
      await settle(tester);
      expect(find.text('meditate'), findsOneWidget);
      expect(_chromeWords(tester), isEmpty);
    });
  });

  testWidgets('form empty, filled, stacked and time sheet are word-free', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seed();
      await tester.pumpWidget(host(const HabitFormScreen()));
      await settle(tester);
      expect(_chromeWords(tester), isEmpty, reason: 'empty form');

      await tester.enterText(find.byKey(const Key('behaviorField')), 'stretch');
      await tester.enterText(find.byKey(const Key('locationField')), 'bedroom');
      await settle(tester);
      expect(_chromeWords(tester), isEmpty, reason: 'filled form');

      await tester.tap(find.byKey(const Key('timeButton')));
      await settle(tester);
      expect(find.byKey(const Key('timeWheel')), findsOneWidget);
      expect(_chromeWords(tester), isEmpty, reason: 'time picker');
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);

      await tester.tap(find.byKey(const Key('anchorPicker')));
      await settle(tester);
      await tester.tap(find.text('meditate').last);
      await settle(tester);
      expect(find.byKey(const Key('locationField')), findsNothing);
      expect(_chromeWords(tester), isEmpty, reason: 'stacked form');
    });
  });
}
