/// A habit's implementation intention drawn as icons plus the user's own
/// words, with no template words around them (textgate).
library;

import 'package:flutter/material.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/ui/theme.dart';

/// Shows `anchor -> behavior` for a stacked habit, otherwise
/// `behavior, clock time, place location`. Empty fields show a dimmed icon
/// only. The full sentence from [renderSentence] is the spoken label.
class IntentionLine extends StatelessWidget {
  /// Creates the line for [habit], stacked after [anchor] when given.
  const IntentionLine({
    required this.habit,
    this.anchor,
    this.dense = false,
    super.key,
  });

  /// The habit to draw.
  final Habit habit;

  /// The habit [habit] is stacked after, if any.
  final Habit? anchor;

  /// Small tiles: one line per piece, stacked vertically, smaller type.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurfaceVariant;
    final style = dense
        ? theme.textTheme.bodySmall
        : theme.textTheme.titleMedium;
    final iconSize = dense ? 14.0 : 18.0;

    Widget piece(IconData? icon, String value) {
      final empty = value.trim().isEmpty;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: iconSize,
              color: dim.withValues(alpha: empty ? 0.4 : 1),
            ),
          if (icon != null && !empty) const SizedBox(width: AppSpacing.xs),
          if (!empty)
            Flexible(
              child: Text(
                value,
                maxLines: dense ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
        ],
      );
    }

    final stackedAfter = anchor;
    final pieces = stackedAfter != null
        ? [
            piece(null, stackedAfter.behavior),
            Icon(
              dense ? Icons.arrow_downward : Icons.arrow_forward,
              size: iconSize,
              color: dim,
            ),
            piece(null, habit.behavior),
          ]
        : [
            piece(Icons.psychology_outlined, habit.behavior),
            piece(Icons.access_time_outlined, habit.time),
            piece(Icons.place_outlined, habit.location),
          ];
    return Semantics(
      label: renderSentence(habit, anchor: anchor),
      excludeSemantics: true,
      child: dense
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pieces,
            )
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: pieces,
            ),
    );
  }
}
