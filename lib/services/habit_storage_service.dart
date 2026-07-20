/// Local persistence for habit definitions and daily completions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:habit_stack/models/completion.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Completions keyed by local date (`YYYY-MM-DD`) to the habit ids
/// completed that day. Date-keyed, not habit-keyed, because the home
/// screen's "today's checklist" read is more common than a single habit's
/// full history.
typedef CompletionsByDate = Map<String, Set<String>>;

/// Singleton service reading/writing `habits.json` and `completions.json`.
///
/// Two files, not one combined JSON: habit definitions (small, rarely
/// written) and daily completions (append-heavy) have different write
/// frequency and shape, mirroring diet_guard's own split between
/// `food_log.json` and its derived `food_bank.json`.
///
/// [readAll]/[writeAll] are the future sync attach point: a later
/// `sync_merge.dart` will wrap these the same way diet_guard's wraps
/// `LogStorageService`. No sync wiring exists yet -- see the
/// `crdt-sync-migration` skill when that work starts.
class HabitStorageService {
  HabitStorageService._(this._habitsFile, this._completionsFile);

  static HabitStorageService? _instance;

  /// Returns the initialized singleton; throws if [init] was not called.
  static HabitStorageService get instance => _instance!;

  final File _habitsFile;
  final File _completionsFile;

  /// Initializes the singleton, pointing at the app's documents directory.
  static Future<HabitStorageService> init() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final svc = HabitStorageService._(
      File(p.join(dir.path, 'habits.json')),
      File(p.join(dir.path, 'completions.json')),
    );
    _instance = svc;
    return svc;
  }

  /// Resets the singleton so [init] can be called again in tests.
  ///
  /// When [testDir] is given, subsequent reads/writes go there instead of
  /// the real documents directory.
  @visibleForTesting
  static void resetForTesting({Directory? testDir}) {
    _instance = testDir == null
        ? null
        : HabitStorageService._(
            File(p.join(testDir.path, 'habits.json')),
            File(p.join(testDir.path, 'completions.json')),
          );
  }

  /// Reads every habit, including archived ones.
  ///
  /// Returns an empty list on a missing or unparsable file.
  Future<List<Habit>> readHabits() async {
    if (!_habitsFile.existsSync()) return [];
    String raw;
    try {
      raw = await _habitsFile.readAsString();
    } on FileSystemException {
      return [];
    }
    Object? data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    if (data is! List) return [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => Habit.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Persists the full habit list, creating the parent directory if needed.
  ///
  /// Writes to a per-process temp file then atomically renames it over the
  /// real one, mirroring diet_guard's `LogStorageService.writeLog`, so a
  /// concurrent reader never sees a half-written file.
  Future<void> writeHabits(List<Habit> habits) async {
    await _habitsFile.parent.create(recursive: true);
    final encoded = habits.map((h) => h.toJson()).toList();
    final tmp = File('${_habitsFile.path}.$pid.tmp');
    await tmp.writeAsString(jsonEncode(encoded));
    await tmp.rename(_habitsFile.path);
  }

  /// Adds [habit] to the stored habit list.
  Future<void> addHabit(Habit habit) async {
    final habits = await readHabits();
    habits.add(habit);
    await writeHabits(habits);
  }

  /// Archives the habit with [habitId], if it exists and isn't already
  /// archived. Archiving, not deleting, so no other habit's
  /// [Habit.anchorHabitId] is ever left dangling.
  Future<void> archiveHabit(String habitId) async {
    final habits = await readHabits();
    for (var i = 0; i < habits.length; i++) {
      if (habits[i].id == habitId && !habits[i].archived) {
        habits[i] = habits[i].copyWithArchived();
        await writeHabits(habits);
        return;
      }
    }
  }

  /// Reads every day's completions.
  ///
  /// Returns an empty map on a missing or unparsable file.
  Future<CompletionsByDate> readCompletions() async {
    if (!_completionsFile.existsSync()) return {};
    String raw;
    try {
      raw = await _completionsFile.readAsString();
    } on FileSystemException {
      return {};
    }
    Object? data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (data is! Map) return {};
    final result = <String, Set<String>>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! List<dynamic>) continue;
      result[key] = value.whereType<String>().toSet();
    }
    return result;
  }

  /// Persists the full completions map, mirroring [writeHabits]'s atomic
  /// temp-file-then-rename pattern.
  Future<void> writeCompletions(CompletionsByDate completions) async {
    await _completionsFile.parent.create(recursive: true);
    final encoded = <String, Object?>{
      for (final entry in completions.entries) entry.key: entry.value.toList(),
    };
    final tmp = File('${_completionsFile.path}.$pid.tmp');
    await tmp.writeAsString(jsonEncode(encoded));
    await tmp.rename(_completionsFile.path);
  }

  /// Toggles whether [habitId] is marked done on [date] (`YYYY-MM-DD`).
  ///
  /// Idempotent in the sense that calling it twice returns to the original
  /// state -- the single tap that marks a habit done today un-marks it on a
  /// second tap.
  Future<bool> toggleCompletion(String habitId, String date) async {
    final completions = await readCompletions();
    final forDate = completions.putIfAbsent(date, () => <String>{});
    final nowDone = !forDate.contains(habitId);
    if (nowDone) {
      forDate.add(habitId);
    } else {
      forDate.remove(habitId);
    }
    await writeCompletions(completions);
    return nowDone;
  }

  /// Returns every date [habitId] was completed on, in stored (unsorted)
  /// order.
  Future<List<Completion>> completionsFor(String habitId) async {
    final completions = await readCompletions();
    return [
      for (final entry in completions.entries)
        if (entry.value.contains(habitId))
          Completion(habitId: habitId, date: entry.key),
    ];
  }
}
