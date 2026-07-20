/// Habit-creation screen -- the app's done-criterion screen: "I create a
/// habit note on my phone and it guides me to fill behavior/time/location,
/// then renders the implementation-intention sentence."
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:habit_stack/models/habit.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
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

  String get _previewSentence {
    final draft = Habit(
      id: _newHabitId,
      behavior: _behaviorController.text.isEmpty
          ? '…'
          : _behaviorController.text,
      time: _timeText.isEmpty ? '--:--' : _timeText,
      location: _locationController.text.isEmpty
          ? '…'
          : _locationController.text,
      createdAt: DateTime.now(),
      anchorHabitId: _anchorHabitId,
    );
    return renderSentence(draft, anchor: _anchor);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
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
      appBar: AppBar(title: const Text('New habit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _behaviorController,
              decoration: const InputDecoration(
                labelText: 'Behavior',
                helperText: '"I will..."',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _anchorHabitId,
              decoration: const InputDecoration(
                labelText: 'Stack after... (optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('None -- use time + location instead'),
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
              const SizedBox(height: 12),
              Tooltip(
                message: 'Pick a time',
                child: OutlinedButton(
                  onPressed: _pickTime,
                  child: Text(_timeText.isEmpty ? 'At...' : 'At $_timeText'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              _previewSentence,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave && !_saving ? _save : null,
              child: const Text('Save habit'),
            ),
          ],
        ),
      ),
    );
  }
}
