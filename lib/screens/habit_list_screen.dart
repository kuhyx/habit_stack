/// Home screen: lists habits, one tap marks today done.
library;

import 'dart:async';

import 'package:design_system/design_system.dart' show FitGrid;
import 'package:flutter/material.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/models/local_date.dart';
import 'package:habit_stack/screens/habit_form_screen.dart';
import 'package:habit_stack/screens/streak_screen.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/services/streak_service.dart';
import 'package:habit_stack/ui/theme.dart';
import 'package:habit_stack/widgets/habit_tile.dart';

/// Shows every non-archived habit as a tile; tapping one toggles whether
/// it's done today (idempotent, no confirmation dialog), long-press opens
/// its actions. Overflow pages horizontally, so the screen never scrolls.
class HabitListScreen extends StatefulWidget {
  /// Creates a [HabitListScreen].
  const HabitListScreen({super.key});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  List<Habit> _habits = const [];
  Set<String> _doneToday = const {};
  Map<String, Set<String>> _datesByHabit = const {};

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
      _datesByHabit = completionDatesByHabit(completions);
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

  Future<void> _showActions(Habit habit) async {
    final archive = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: const Text('Archive habit'),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (archive != true) return;
    await HabitStorageService.instance.archiveHabit(habit.id);
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
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const StreakScreen()));
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
      body: SafeArea(
        top: false,
        child: _habits.isEmpty
            ? const Center(child: Text('No habits yet -- add one below.'))
            : FitGrid(
                itemCount: _habits.length,
                columns: 2,
                minSquare: 0.7,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxl + AppSpacing.xl,
                ),
                itemBuilder: (context, index) {
                  final habit = _habits[index];
                  final dates = _datesByHabit[habit.id] ?? const <String>{};
                  return HabitTile(
                    sentence: renderSentence(habit, anchor: _anchorOf(habit)),
                    done: _doneToday.contains(habit.id),
                    streak: currentStreak(dates),
                    onTap: () => unawaited(_toggle(habit)),
                    onLongPress: () => unawaited(_showActions(habit)),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHabit,
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
    );
  }
}
