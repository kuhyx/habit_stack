/// "Don't break the chain" view: one tile per habit with its current streak
/// and a month heatmap, paged horizontally so the screen never scrolls.
library;

import 'dart:async';

import 'package:design_system/design_system.dart' show FitGrid;
import 'package:flutter/material.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/services/streak_service.dart';
import 'package:habit_stack/ui/theme.dart';
import 'package:habit_stack/widgets/month_heatmap.dart';

/// Shows every non-archived habit as a streak + month-heatmap tile.
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
    final byHabit = completionDatesByHabit(completions);
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
      body: SafeArea(
        top: false,
        child: _habits.isEmpty
            ? const Center(child: Text('No habits yet.'))
            : FitGrid(
                itemCount: _habits.length,
                columns: 2,
                minSquare: 1.2,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                itemBuilder: (context, index) {
                  final habit = _habits[index];
                  final dates = _datesByHabit[habit.id] ?? const <String>{};
                  return _StreakTile(
                    behavior: habit.behavior,
                    streak: currentStreak(dates),
                    dates: dates,
                  );
                },
              ),
      ),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({
    required this.behavior,
    required this.streak,
    required this.dates,
  });

  final String behavior;
  final int streak;
  final Set<String> dates;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              behavior,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Streak: $streak day${streak == 1 ? '' : 's'}'),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: MonthHeatmap(month: now, today: now, doneDates: dates),
            ),
          ],
        ),
      ),
    );
  }
}
