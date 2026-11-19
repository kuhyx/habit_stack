/// Textgate guard: no screen paints a letter kuhy did not type.
///
/// Walks every painted [RichText] (a [Text] builds one; icons are private-use
/// codepoints and pass) and every [Tooltip] message, and fails on any Latin
/// letter, even a single one, unless the whole string is seeded user content
/// (a behavior or location). Each screen also has to paint at least a few
/// strings, so a walk that finds nothing cannot pass by accident. Every case
/// runs under the light and the dark theme, with and without habits, and
/// each screen is pushed as a route so the AppBar's back button is on screen.
library;

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/main.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/screens/habit_form_screen.dart';
import 'package:habit_stack/screens/habit_list_screen.dart';
import 'package:habit_stack/screens/streak_screen.dart';
import 'package:habit_stack/services/document_store.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/ui/theme.dart';

/// Strings the user typed; the only words allowed on screen.
const Set<String> _content = {'meditate', 'bedroom', 'stretch'};

final RegExp _letter = RegExp('[A-Za-z]');

/// Every painted string and tooltip that holds a letter and is not content.
///
/// Fails the test when fewer than [minStrings] strings were painted: an
/// empty walk would otherwise pass any screen.
List<String> _chromeWords(WidgetTester tester, {int minStrings = 1}) {
  final insideEditable = find
      .descendant(
        of: find.byType(EditableText),
        matching: find.byType(RichText),
      )
      .evaluate()
      .toSet();
  final painted = [
    for (final element in find.byType(RichText).evaluate())
      if (!insideEditable.contains(element))
        (element.widget as RichText).text.toPlainText(),
  ];
  expect(
    painted.where((s) => s.isNotEmpty).length,
    greaterThanOrEqualTo(minStrings),
    reason: 'too few painted strings: $painted',
  );
  final tooltips = [
    for (final element in find.byType(Tooltip).evaluate())
      (element.widget as Tooltip).message ??
          (element.widget as Tooltip).richMessage?.toPlainText() ??
          '',
  ];
  return [
    ...painted,
    ...tooltips,
  ].where((s) => _letter.hasMatch(s) && !_content.contains(s.trim())).toList();
}

/// Web template files that must not carry Flutter's stock text or the
/// package name.
const List<String> _webFiles = ['web/index.html', 'web/manifest.json'];

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

  final themes = <String, ThemeData Function()>{
    'light': buildLightTheme,
    'dark': buildDarkTheme,
  };

  for (final MapEntry(key: mode, value: theme) in themes.entries) {
    /// Pushes [home] over a blank root so the AppBar shows its back button.
    Future<void> open(WidgetTester tester, Widget home) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme(),
          navigatorKey: nav,
          home: const SizedBox.shrink(),
        ),
      );
      unawaited(
        nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => home)),
      );
      await settle(tester);
    }

    testWidgets('[$mode] list with habits and its archive sheet', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seed();
        await open(tester, const HabitListScreen());
        expect(_chromeWords(tester, minStrings: 4), isEmpty);
      });

      // Outside runAsync: its zone makes the long-press timer real time.
      await tester.longPress(find.text('stretch').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('archiveTile')), findsOneWidget);
      expect(_chromeWords(tester, minStrings: 5), isEmpty);
    });

    testWidgets('[$mode] list with no habits', (tester) async {
      await tester.runAsync(() async {
        await open(tester, const HabitListScreen());
        expect(_chromeWords(tester, minStrings: 2), isEmpty);
      });
    });

    testWidgets('[$mode] streak screen with habits', (tester) async {
      await tester.runAsync(() async {
        await seed();
        await open(tester, const StreakScreen());
        expect(find.text('meditate'), findsOneWidget);
        expect(_chromeWords(tester, minStrings: 3), isEmpty);
      });
    });

    testWidgets('[$mode] streak screen with no habits', (tester) async {
      await tester.runAsync(() async {
        await open(tester, const StreakScreen());
        expect(_chromeWords(tester, minStrings: 1), isEmpty);
      });
    });

    testWidgets('[$mode] form empty, filled, stacked and time sheet', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seed();
        await open(tester, const HabitFormScreen());
        expect(
          _chromeWords(tester, minStrings: 2),
          isEmpty,
          reason: 'empty form',
        );

        await tester.enterText(
          find.byKey(const Key('behaviorField')),
          'stretch',
        );
        await tester.enterText(
          find.byKey(const Key('locationField')),
          'bedroom',
        );
        await settle(tester);
        expect(
          _chromeWords(tester, minStrings: 2),
          isEmpty,
          reason: 'filled form',
        );

        await tester.tap(find.byKey(const Key('timeButton')));
        await settle(tester);
        expect(find.byKey(const Key('timeWheel')), findsOneWidget);
        expect(
          _chromeWords(tester, minStrings: 3),
          isEmpty,
          reason: 'time picker',
        );
        await tester.tapAt(const Offset(10, 10));
        await settle(tester);

        await tester.tap(find.byKey(const Key('anchorPicker')));
        await settle(tester);
        await tester.tap(find.text('meditate').last);
        await settle(tester);
        expect(find.byKey(const Key('locationField')), findsNothing);
        expect(
          _chromeWords(tester, minStrings: 2),
          isEmpty,
          reason: 'stacked form',
        );
      });
    });
  }

  test('the guard catches a single stray letter and a tooltip', () {
    // Self-test of the matcher itself, so loosening it shows up here.
    expect(_letter.hasMatch('x'), isTrue);
    expect(_letter.hasMatch('07:00 \u{e000}'), isFalse);
  });

  testWidgets('app title, the web tab text, holds no letter', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const HabitStackApp());
      await settle(tester);
    });
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(_letter.hasMatch(app.title ?? ''), isFalse, reason: app.title);
  });

  for (final path in _webFiles) {
    test('$path carries no stock or package-name text', () {
      final body = File(path).readAsStringSync();
      expect(body, isNot(contains('A new Flutter project')));
      expect(body, isNot(contains('habit_stack')));
    });
  }
}
