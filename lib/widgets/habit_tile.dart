/// A habit as a tile: streak ring with done state, sentence, streak count.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:habit_stack/ui/theme.dart';

/// Streak length at which the ring is full.
const int ringFullStreak = 7;

/// Tap toggles today's completion; long-press opens the habit's actions.
class HabitTile extends StatelessWidget {
  /// Creates a tile for one habit.
  const HabitTile({
    required this.sentence,
    required this.done,
    required this.streak,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  /// The rendered implementation-intention sentence.
  final String sentence;

  /// Whether the habit is done today.
  final bool done;

  /// Current streak in days.
  final int streak;

  /// Called on tap.
  final VoidCallback onTap;

  /// Called on long-press.
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final success = theme.extension<AppStatusColors>()!.success;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: AppSpacing.xxl,
                    child: CircularProgressIndicator(
                      value: math.min(streak, ringFullStreak) / ringFullStreak,
                      strokeWidth: AppSpacing.xs,
                      color: success,
                      backgroundColor: scheme.outline,
                    ),
                  ),
                  Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    color: (done ? success : scheme.onSurfaceVariant)
                        .withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Streak $streak',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
