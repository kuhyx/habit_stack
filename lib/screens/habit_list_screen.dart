/// Home screen: lists habits, one tap marks today done.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/models/local_date.dart';
import 'package:habit_stack/screens/habit_form_screen.dart';
import 'package:habit_stack/screens/streak_screen.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/ui/theme.dart';

/// Shows every non-archived habit's rendered sentence; tapping a row
/// toggles whether it's done today. Idempotent, no confirmation dialog --
/// matching the app's own "make it easy" premise.
class HabitListScreen extends StatefulWidget {
  /// Creates a [HabitListScreen].
  const HabitListScreen({super.key});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  List<Habit> _habits = const [];
  Set<String> _doneToday = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final habits = await HabitStorageService.instance.readHabits();
    final completions = await HabitStorageService.instance.readCompletions();
    if (!mounted) return;
    setState(() {
      _habits = habits.where((h) => !h.archived).toList();
      _doneToday = completions[localDateKey(DateTime.now())] ?? const {};
    });
  }

  Habit? _anchorOf(Habit habit) {
    final id = habit.anchorHabitId;
    if (id == null) return null;
    for (final h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> _toggle(Habit habit) async {
    await HabitStorageService.instance.toggleCompletion(
      habit.id,
      localDateKey(DateTime.now()),
    );
    await _refresh();
  }

  Future<void> _addHabit() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const HabitFormScreen()));
    await _refresh();
  }

  void _openStreaks() {
    // No unawaited(): Navigator.push is annotated @awaitNotRequired, so
    // wrapping it now trips unnecessary_unawaited.
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const StreakScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Stack'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.local_fire_department,
              // Dimmed relative to the adjacent title text (rule 28).
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Streaks',
            onPressed: _openStreaks,
          ),
        ],
      ),
      body: _habits.isEmpty
          ? const Center(child: Text('No habits yet -- add one below.'))
          : ListView.builder(
              itemCount: _habits.length,
              itemBuilder: (context, index) {
                final habit = _habits[index];
                final done = _doneToday.contains(habit.id);
                final colorScheme = Theme.of(context).colorScheme;
                final success = Theme.of(
                  context,
                ).extension<AppStatusColors>()!.success;
                return ListTile(
                  leading: Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    // Dimmed relative to the row's title text (rule 28).
                    color: (done ? success : colorScheme.onSurfaceVariant)
                        .withValues(alpha: 0.8),
                  ),
                  title: Text(renderSentence(habit, anchor: _anchorOf(habit))),
                  onTap: () => unawaited(_toggle(habit)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHabit,
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
    );
  }
}
