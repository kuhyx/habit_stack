import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/services/habit_storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_stack_test_');
    HabitStorageService.resetForTesting(testDir: tempDir);
  });

  tearDown(() async {
    HabitStorageService.resetForTesting();
    await tempDir.delete(recursive: true);
  });

  Habit habit({String id = 'h1', String? anchorHabitId}) => Habit(
    id: id,
    behavior: 'meditate',
    time: '07:00',
    location: 'bedroom',
    createdAt: DateTime(2026, 1, 1),
    anchorHabitId: anchorHabitId,
  );

  group('readHabits', () {
    test('returns an empty list when no file exists yet', () async {
      expect(await HabitStorageService.instance.readHabits(), isEmpty);
    });

    test('returns an empty list for unparsable JSON', () async {
      await File('${tempDir.path}/habits.json').writeAsString('not json');
      expect(await HabitStorageService.instance.readHabits(), isEmpty);
    });

    test('returns an empty list when the JSON root is not a list', () async {
      await File('${tempDir.path}/habits.json').writeAsString('{}');
      expect(await HabitStorageService.instance.readHabits(), isEmpty);
    });

    test(
      'returns an empty list when the file exists but is unreadable',
      () async {
        final file = File('${tempDir.path}/habits.json');
        await file.writeAsString('[]');
        await Process.run('chmod', ['000', file.path]);
        addTearDown(() => Process.runSync('chmod', ['644', file.path]));
        expect(await HabitStorageService.instance.readHabits(), isEmpty);
      },
      skip: Platform.isWindows ? 'chmod is POSIX-only' : false,
    );
  });

  group('addHabit / writeHabits', () {
    test('addHabit appends and readHabits round-trips it', () async {
      await HabitStorageService.instance.addHabit(habit());
      final habits = await HabitStorageService.instance.readHabits();
      expect(habits.single.id, 'h1');
    });

    test('two added habits both persist', () async {
      await HabitStorageService.instance.addHabit(habit(id: 'h1'));
      await HabitStorageService.instance.addHabit(habit(id: 'h2'));
      final habits = await HabitStorageService.instance.readHabits();
      expect(habits.map((h) => h.id), ['h1', 'h2']);
    });

    test('writeHabits does not leave a temp file behind', () async {
      await HabitStorageService.instance.writeHabits([habit()]);
      final entries = tempDir.listSync().map((e) => e.path);
      expect(entries, everyElement(isNot(contains('.tmp'))));
    });
  });

  group('archiveHabit', () {
    test('marks the matching habit archived, others untouched', () async {
      await HabitStorageService.instance.addHabit(habit(id: 'h1'));
      await HabitStorageService.instance.addHabit(habit(id: 'h2'));
      await HabitStorageService.instance.archiveHabit('h1');
      final habits = await HabitStorageService.instance.readHabits();
      expect(habits.firstWhere((h) => h.id == 'h1').archived, isTrue);
      expect(habits.firstWhere((h) => h.id == 'h2').archived, isFalse);
    });

    test('does not re-archive an already-archived habit', () async {
      await HabitStorageService.instance.addHabit(
        habit(id: 'h1').copyWithArchived(),
      );
      await HabitStorageService.instance.archiveHabit('h1');
      // No error; still archived.
      final habits = await HabitStorageService.instance.readHabits();
      expect(habits.single.archived, isTrue);
    });

    test('silently does nothing for an unknown id', () async {
      await HabitStorageService.instance.addHabit(habit(id: 'h1'));
      await HabitStorageService.instance.archiveHabit('no-such-id');
      final habits = await HabitStorageService.instance.readHabits();
      expect(habits.single.archived, isFalse);
    });
  });

  group('readCompletions', () {
    test('returns an empty map when no file exists yet', () async {
      expect(await HabitStorageService.instance.readCompletions(), isEmpty);
    });

    test('returns an empty map for unparsable JSON', () async {
      await File(
        '${tempDir.path}/completions.json',
      ).writeAsString('not json');
      expect(await HabitStorageService.instance.readCompletions(), isEmpty);
    });

    test('returns an empty map when the JSON root is not a map', () async {
      await File('${tempDir.path}/completions.json').writeAsString('[]');
      expect(await HabitStorageService.instance.readCompletions(), isEmpty);
    });

    test('skips a date key whose value is not a list', () async {
      await File(
        '${tempDir.path}/completions.json',
      ).writeAsString(jsonEncode({'2026-06-22': 'not a list'}));
      expect(await HabitStorageService.instance.readCompletions(), isEmpty);
    });

    test(
      'returns an empty map when the file exists but is unreadable',
      () async {
        final file = File('${tempDir.path}/completions.json');
        await file.writeAsString('{}');
        await Process.run('chmod', ['000', file.path]);
        addTearDown(() => Process.runSync('chmod', ['644', file.path]));
        expect(await HabitStorageService.instance.readCompletions(), isEmpty);
      },
      skip: Platform.isWindows ? 'chmod is POSIX-only' : false,
    );
  });

  group('toggleCompletion', () {
    test('marks a habit done on the given date, returning true', () async {
      final done = await HabitStorageService.instance.toggleCompletion(
        'h1',
        '2026-06-22',
      );
      expect(done, isTrue);
      final completions = await HabitStorageService.instance.readCompletions();
      expect(completions['2026-06-22'], {'h1'});
    });

    test('toggling again un-marks it, returning false', () async {
      await HabitStorageService.instance.toggleCompletion('h1', '2026-06-22');
      final done = await HabitStorageService.instance.toggleCompletion(
        'h1',
        '2026-06-22',
      );
      expect(done, isFalse);
      final completions = await HabitStorageService.instance.readCompletions();
      expect(completions['2026-06-22'], isEmpty);
    });

    test('does not disturb another habit on the same date', () async {
      await HabitStorageService.instance.toggleCompletion('h1', '2026-06-22');
      await HabitStorageService.instance.toggleCompletion('h2', '2026-06-22');
      final completions = await HabitStorageService.instance.readCompletions();
      expect(completions['2026-06-22'], {'h1', 'h2'});
    });
  });

  group('completionsFor', () {
    test('returns every date a habit was completed on', () async {
      await HabitStorageService.instance.toggleCompletion('h1', '2026-06-20');
      await HabitStorageService.instance.toggleCompletion('h1', '2026-06-21');
      await HabitStorageService.instance.toggleCompletion('h2', '2026-06-21');
      final completions = await HabitStorageService.instance.completionsFor(
        'h1',
      );
      expect(completions.map((c) => c.date).toSet(), {
        '2026-06-20',
        '2026-06-21',
      });
    });

    test('returns empty for a habit with no completions', () async {
      expect(
        await HabitStorageService.instance.completionsFor('h1'),
        isEmpty,
      );
    });
  });
}
