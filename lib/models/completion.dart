/// A single day's completion record for a habit.
library;

import 'package:flutter/foundation.dart';

/// Marks that [habitId] was completed on [date].
///
/// Modeled separately from [Habit] (in `habit.dart`): a habit's definition
/// and a day's completion record are different concerns with different
/// write frequency and shape. Presence/absence per (habit, day) is all v1
/// needs -- there is no id or timestamp beyond the date key, since a habit
/// is either done that day or not, not logged multiple times per day.
@immutable
class Completion {
  /// Creates a [Completion] from its stored fields.
  const Completion({required this.habitId, required this.date});

  /// Builds a [Completion] from its JSON map representation.
  factory Completion.fromJson(Map<String, dynamic> json) => Completion(
    habitId: json['habit_id'] as String,
    date: json['date'] as String,
  );

  /// The [Habit.id] this completion belongs to.
  final String habitId;

  /// Local date key in `YYYY-MM-DD` form.
  final String date;

  /// Returns the JSON map representation.
  Map<String, Object?> toJson() => {'habit_id': habitId, 'date': date};

  @override
  bool operator ==(Object other) =>
      other is Completion && other.habitId == habitId && other.date == date;

  @override
  int get hashCode => Object.hash(habitId, date);

  @override
  String toString() => 'Completion(habitId: $habitId, date: $date)';
}
