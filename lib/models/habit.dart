/// A habit definition: an Atomic Habits implementation-intention, with an
/// optional habit-stacking anchor.
library;

import 'package:flutter/foundation.dart';

/// One habit's structured implementation-intention: "I will [behavior] at
/// [time] in [location]", optionally stacked after another habit instead
/// ("After [anchor], I will [behavior]").
///
/// Habits are implicitly daily -- there is no frequency field. The streak
/// logic in `streak_service.dart` depends on this: a habit intended for,
/// say, three days a week would need a model change before its streak could
/// be computed correctly.
@immutable
class Habit {
  /// Creates a [Habit] from its stored fields.
  const Habit({
    required this.id,
    required this.behavior,
    required this.time,
    required this.location,
    required this.createdAt,
    this.anchorHabitId,
    this.archived = false,
  });

  /// Builds a [Habit] from its JSON map representation.
  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: json['id'] as String,
    behavior: json['behavior'] as String,
    time: json['time'] as String,
    location: json['location'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    anchorHabitId: json['anchor_habit_id'] as String?,
    archived: json['archived'] as bool? ?? false,
  );

  /// Stable identity (UUID v4).
  final String id;

  /// "I will [behavior]" -- free text.
  final String behavior;

  /// A 24h clock time in `HH:mm` form, e.g. `"07:00"` -- not a
  /// day-of-week recurrence.
  final String time;

  /// "in [location]" -- free text.
  final String location;

  /// When this habit was created.
  final DateTime createdAt;

  /// Habit-stacking anchor: the id of another [Habit] this one is stacked
  /// after, or null for a standalone implementation-intention. A real
  /// reference (not a text field) so a chain can be queried and rendered.
  final String? anchorHabitId;

  /// Soft-delete flag. Archiving (not deleting) a habit that other habits
  /// anchor to avoids ever leaving a dangling [anchorHabitId] reference.
  final bool archived;

  /// Returns the JSON map representation.
  Map<String, Object?> toJson() => {
    'id': id,
    'behavior': behavior,
    'time': time,
    'location': location,
    'created_at': createdAt.toIso8601String(),
    if (anchorHabitId != null) 'anchor_habit_id': anchorHabitId,
    if (archived) 'archived': true,
  };

  /// Returns a copy of this habit archived.
  Habit copyWithArchived() => Habit(
    id: id,
    behavior: behavior,
    time: time,
    location: location,
    createdAt: createdAt,
    anchorHabitId: anchorHabitId,
    archived: true,
  );

  @override
  bool operator ==(Object other) =>
      other is Habit &&
      other.id == id &&
      other.behavior == behavior &&
      other.time == time &&
      other.location == location &&
      other.createdAt == createdAt &&
      other.anchorHabitId == anchorHabitId &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(
    id,
    behavior,
    time,
    location,
    createdAt,
    anchorHabitId,
    archived,
  );

  @override
  String toString() =>
      'Habit(id: $id, behavior: $behavior, time: $time, '
      'location: $location, anchorHabitId: $anchorHabitId, '
      'archived: $archived)';
}

/// Renders [habit]'s implementation-intention sentence.
///
/// Two mutually exclusive shapes, matching the two prompts Atomic Habits
/// describes: a standalone intention ("I will X at T in L") or a
/// habit-stack ("After Y, I will X") when [anchor] is given. The stacked
/// form intentionally does not also render time/location -- the two forms
/// are alternatives, not additive.
String renderSentence(Habit habit, {Habit? anchor}) {
  if (anchor != null) {
    return 'After ${anchor.behavior}, I will ${habit.behavior}';
  }
  return 'I will ${habit.behavior} at ${habit.time} in ${habit.location}';
}

/// Returns true if setting [habitId]'s anchor to [candidateAnchorId] would
/// create a cycle in the habit-stacking chain.
///
/// Walks the candidate's own anchor chain looking for [habitId]; a cycle
/// exists exactly when the walk reaches back to the habit being edited (or
/// immediately if the candidate anchor *is* the habit itself). Called both
/// when filtering the "stack after..." picker's candidate list and again on
/// save, since the picker's candidate list is computed before every field
/// edit and could go stale between renders.
bool wouldCreateCycle(
  String candidateAnchorId,
  String habitId,
  List<Habit> allHabits,
) {
  if (candidateAnchorId == habitId) return true;
  final byId = {for (final h in allHabits) h.id: h};
  var currentId = candidateAnchorId;
  final visited = <String>{};
  while (true) {
    if (!visited.add(currentId)) return false; // pre-existing unrelated loop
    final current = byId[currentId];
    if (current?.anchorHabitId == null) return false;
    if (current!.anchorHabitId == habitId) return true;
    currentId = current.anchorHabitId!;
  }
}
