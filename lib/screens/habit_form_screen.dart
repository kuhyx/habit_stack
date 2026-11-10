/// Habit-creation screen -- the app's done-criterion screen: "I create a
/// habit note on my phone and it guides me to fill behavior/time/location,
/// then renders the implementation-intention sentence."
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/ui/theme.dart';
import 'package:habit_stack/widgets/intention_line.dart';
import 'package:habit_stack/widgets/time_sheet.dart';
import 'package:uuid/uuid.dart';

/// Prompts for behavior, time, and location (or a habit-stacking anchor
/// instead), live-rendering the resulting implementation-intention
/// sentence as the user fills each field in.
class HabitFormScreen extends StatefulWidget {
  /// Creates a [HabitFormScreen].
  const HabitFormScreen({super.key});

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  final _behaviorController = TextEditingController();
  final _locationController = TextEditingController();

  /// Generated up-front (not on save) so [wouldCreateCycle] has a real,
  /// stable id to check the anchor picker's candidates against.
  final String _newHabitId = const Uuid().v4();

  TimeOfDay? _time;
  String? _anchorHabitId;
  List<Habit> _existingHabits = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHabits());
  }

  @override
  void dispose() {
    _behaviorController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadHabits() async {
    final habits = await HabitStorageService.instance.readHabits();
    if (!mounted) return;
    setState(() => _existingHabits = habits);
  }

  List<Habit> get _anchorCandidates => _existingHabits
      .where((h) => !h.archived)
      .where((h) => !wouldCreateCycle(h.id, _newHabitId, _existingHabits))
      .toList();

  String get _timeText => _time == null
      ? ''
      : '${_time!.hour.toString().padLeft(2, '0')}:'
            '${_time!.minute.toString().padLeft(2, '0')}';

  Habit? get _anchor {
    final id = _anchorHabitId;
    if (id == null) return null;
    for (final h in _existingHabits) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// The habit as typed so far, for the live [IntentionLine] preview.
  Habit get _draft => Habit(
    id: _newHabitId,
    behavior: _behaviorController.text,
    time: _timeText,
    location: _locationController.text,
    createdAt: DateTime.now(),
    anchorHabitId: _anchorHabitId,
  );

  Future<void> _pickTime() async {
    final picked = await showTimeSheet(context, _time ?? TimeOfDay.now());
    if (picked == null) return;
    setState(() => _time = picked);
  }

  bool get _canSave =>
      _behaviorController.text.trim().isNotEmpty &&
      (_anchorHabitId != null ||
          (_timeText.isNotEmpty && _locationController.text.trim().isNotEmpty));

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final habit = Habit(
      id: _newHabitId,
      behavior: _behaviorController.text.trim(),
      time: _timeText,
      location: _locationController.text.trim(),
      createdAt: DateTime.now(),
      anchorHabitId: _anchorHabitId,
    );
    await HabitStorageService.instance.addHabit(habit);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('behaviorField'),
              controller: _behaviorController,
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.psychology_outlined,
                  semanticLabel: 'Behavior',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              key: const Key('anchorPicker'),
              initialValue: _anchorHabitId,
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.call_split_outlined,
                  semanticLabel: 'Stack after',
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  child: Icon(Icons.block_outlined, size: 18),
                ),
                for (final h in _anchorCandidates)
                  DropdownMenuItem<String?>(
                    value: h.id,
                    child: Text(h.behavior),
                  ),
              ],
              onChanged: (value) => setState(() => _anchorHabitId = value),
            ),
            if (_anchorHabitId == null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                key: const Key('timeButton'),
                onPressed: _pickTime,
                child: _timeText.isEmpty
                    ? const Icon(
                        Icons.access_time_outlined,
                        semanticLabel: 'Pick a time',
                      )
                    : Text(_timeText),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('locationField'),
                controller: _locationController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.place_outlined,
                    semanticLabel: 'Location',
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            // <= the 16px outer scroll padding above (rule 19).
            const SizedBox(height: AppSpacing.md),
            IntentionLine(
              key: const Key('preview'),
              habit: _draft,
              anchor: _anchor,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('saveButton'),
              onPressed: _canSave && !_saving ? _save : null,
              child: const Icon(
                Icons.save_outlined,
                semanticLabel: 'Save habit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
