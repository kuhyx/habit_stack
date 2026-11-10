import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/screens/habit_list_screen.dart';
import 'package:habit_stack/screens/streak_screen.dart';
import 'package:habit_stack/services/document_store.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/ui/theme.dart';

/// Pixel 6a geometry (build-mobile-app R7): 1080x2400 @ 2.625 with the real
/// status bar (132 px) and nav bar (63 px) insets.
void pixel6a(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625
    ..padding = const FakeViewPadding(top: 132, bottom: 63);
  addTearDown(tester.view.reset);
}

/// Every vertical Scrollable must have nothing to scroll to.
void expectNoVerticalScroll(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    final axis = state.position.axis;
    if (axis != Axis.vertical) continue;
    expect(
      state.position.maxScrollExtent,
      0,
      reason: 'a vertical Scrollable can still scroll',
    );
  }
}

void main() {
  setUp(
    () => HabitStorageService.resetForTesting(store: InMemoryDocumentStore()),
  );
  tearDown(HabitStorageService.resetForTesting);

  Future<void> addHabits(int n) async {
    for (var i = 0; i < n; i++) {
      await HabitStorageService.instance.addHabit(
        Habit(
          id: 'h$i',
          behavior: 'habit number $i',
          time: '07:00',
          location: 'bedroom',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
    }
  }

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  for (final count in [1, 30]) {
    testWidgets('habit list fits one screen with $count habits', (
      tester,
    ) async {
      pixel6a(tester);
      await tester.runAsync(() async {
        await addHabits(count);
        await tester.pumpWidget(
          MaterialApp(theme: buildLightTheme(), home: HabitListScreen()),
        );
        await settle(tester);

        expectNoVerticalScroll(tester);
        expect(find.text('habit number 0').hitTestable(), findsOneWidget);
        expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);
      });
    });

    testWidgets('streak screen fits one screen with $count habits', (
      tester,
    ) async {
      pixel6a(tester);
      await tester.runAsync(() async {
        await addHabits(count);
        await tester.pumpWidget(
          MaterialApp(theme: buildLightTheme(), home: const StreakScreen()),
        );
        await settle(tester);

        expectNoVerticalScroll(tester);
        expect(find.text('habit number 0').hitTestable(), findsOneWidget);
      });
    });
  }

  Future<void> pumpList(WidgetTester tester, int count) async {
    await tester.runAsync(() async {
      await addHabits(count);
      await tester.pumpWidget(
        MaterialApp(theme: buildLightTheme(), home: HabitListScreen()),
      );
      await settle(tester);
    });
  }

  // Gestures run outside runAsync: its zone makes the long-press timer real
  // time, which pump(Duration) can never advance.
  testWidgets('30 habits page horizontally; the last one is reachable', (
    tester,
  ) async {
    pixel6a(tester);
    await pumpList(tester, 30);
    final last = find.text('habit number 29');
    expect(last.hitTestable(), findsNothing);

    var swipes = 0;
    while (last.hitTestable().evaluate().isEmpty && swipes < 5) {
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
      await tester.pumpAndSettle();
      swipes++;
    }
    expect(last.hitTestable(), findsOneWidget);
    expect(swipes, greaterThan(0));
  });

  testWidgets('long-press opens a sheet; Archive removes the habit', (
    tester,
  ) async {
    pixel6a(tester);
    await pumpList(tester, 2);
    final first = find.text('habit number 0');
    final second = find.text('habit number 1');

    await tester.longPress(second);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archiveTile')));
    await tester.runAsync(() => settle(tester));

    expect(second, findsNothing);
    expect(first, findsOneWidget);
  });
}
