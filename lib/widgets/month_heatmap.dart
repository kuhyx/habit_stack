/// Monday-first month grid; days after `today` are blank, not "missed".
library;

import 'package:flutter/material.dart';
import 'package:habit_stack/models/local_date.dart';
import 'package:habit_stack/ui/theme.dart';

/// One cell per day of [month], filled when its date is in [doneDates].
class MonthHeatmap extends StatelessWidget {
  /// Creates a heatmap of [month] marking the [doneDates] (`YYYY-MM-DD`).
  const MonthHeatmap({
    required this.month,
    required this.today,
    required this.doneDates,
    super.key,
  });

  /// Any date inside the month to draw.
  final DateTime month;

  /// The current day.
  final DateTime today;

  /// Local date keys the habit was completed on.
  final Set<String> doneDates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = Theme.of(context).extension<AppStatusColors>()!.success;
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - DateTime.monday;
    final rows = ((lead + days) / 7).ceil();

    Widget cell(int slot) {
      final day = slot - lead + 1;
      if (day < 1 || day > days) return const Spacer();
      final date = DateTime(month.year, month.month, day);
      final Color? fill;
      if (date.isAfter(today)) {
        fill = null;
      } else if (doneDates.contains(localDateKey(date))) {
        fill = success;
      } else {
        fill = scheme.surfaceContainerHighest;
      }
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppSpacing.xs / 2),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Row(children: [for (var c = 0; c < 7; c++) cell(r * 7 + c)]),
          ),
      ],
    );
  }
}
