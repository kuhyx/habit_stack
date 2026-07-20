/// "Don't break the chain" view: per-habit current streak and a recent-day
/// strip showing which of the last 7 days were completed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/models/local_date.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/services/streak_service.dart';

/// Days shown per habit in the recent-activity strip.
const int _recentDayCount = 7;

/// Lists every non-archived habit with its current streak count and a
/// 7-day completed/not-completed strip.
class StreakScreen extends StatefulWidget {
  /// Creates a [StreakScreen].
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  List<Habit> _habits = const [];
  Map<String, Set<String>> _datesByHabit = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final habits = await HabitStorageService.instance.readHabits();
    final completions = await HabitStorageService.instance.readCompletions();
    final byHabit = <String, Set<String>>{};
    for (final entry in completions.entries) {
      for (final habitId in entry.value) {
        byHabit.putIfAbsent(habitId, () => {}).add(entry.key);
      }
    }
    if (!mounted) return;
    setState(() {
      _habits = habits.where((h) => !h.archived).toList();
      _datesByHabit = byHabit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streaks')),
      body: _habits.isEmpty
          ? const Center(child: Text('No habits yet.'))
          : ListView.builder(
              itemCount: _habits.length,
              itemBuilder: (context, index) {
                final habit = _habits[index];
                final dates = _datesByHabit[habit.id] ?? const <String>{};
                final streak = currentStreak(dates);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.behavior,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('Streak: $streak day${streak == 1 ? '' : 's'}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (
                            var offset = _recentDayCount - 1;
                            offset >= 0;
                            offset--
                          )
                            _DayCell(
                              done: dates.contains(
                                localDateKey(
                                  DateTime.now().subtract(
                                    Duration(days: offset),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: done ? Colors.green : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }
}
