/// A text-free time picker: 24-hour number wheels and a check button.
///
/// Replaces Material's `showTimePicker`, whose "Select time", "Cancel" and
/// "OK" labels are strings, not icons (textgate).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:habit_stack/ui/theme.dart';

/// Opens the sheet at [initial]; returns the chosen time, or null when the
/// sheet is dismissed without the check button.
Future<TimeOfDay?> showTimeSheet(BuildContext context, TimeOfDay initial) {
  var picked = initial;
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                key: const Key('timeWheel'),
                mode: CupertinoDatePickerMode.time,
                // 12-hour mode would paint AM/PM.
                use24hFormat: true,
                initialDateTime: DateTime(
                  2000,
                  1,
                  1,
                  initial.hour,
                  initial.minute,
                ),
                onDateTimeChanged: (value) =>
                    picked = TimeOfDay.fromDateTime(value),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('timeConfirm'),
              onPressed: () => Navigator.of(context).pop(picked),
              child: const Icon(Icons.check, semanticLabel: 'Set time'),
            ),
          ],
        ),
      ),
    ),
  );
}
