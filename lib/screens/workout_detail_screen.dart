import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/exercise_repository.dart';
import '../data/personal_record_repository.dart';
import '../data/workout_repository.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import '../utils/enum_labels.dart';
import '../utils/format_utils.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;
  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _workoutRepo = WorkoutRepository();
  final _exerciseRepo = ExerciseRepository();
  final _prRepo = PersonalRecordRepository();

  Workout? _workout;
  List<WorkoutExercise> _workoutExercises = [];
  Map<String, Exercise> _exerciseLookup = {};
  Map<String, List<WorkoutSet>> _setsByWorkoutExercise = {};
  bool _loading = true;
  bool _changed = false;
  final Set<String> _touchedExerciseIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final workout = await _workoutRepo.getWorkoutById(widget.workoutId);
    if (workout == null) {
      if (mounted) Navigator.of(context).pop(_changed);
      return;
    }
    final exercises = await _workoutRepo.getExercisesForWorkout(widget.workoutId);
    final lookup = <String, Exercise>{};
    final setsMap = <String, List<WorkoutSet>>{};
    for (final we in exercises) {
      final exercise = await _exerciseRepo.getExerciseById(we.exerciseId);
      if (exercise != null) lookup[we.exerciseId] = exercise;
      setsMap[we.id] = await _workoutRepo.getSetsForWorkoutExercise(we.id);
    }
    if (!mounted) return;
    setState(() {
      _workout = workout;
      _workoutExercises = exercises;
      _exerciseLookup = lookup;
      _setsByWorkoutExercise = setsMap;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _workout!.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      final updated = _workout!.copyWith(name: newName.trim());
      await _workoutRepo.updateWorkout(updated);
      setState(() {
        _workout = updated;
        _changed = true;
      });
    }
  }

  Future<void> _deleteWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This workout and all its logged sets will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final affectedExerciseIds = _workoutExercises.map((we) => we.exerciseId).toSet();
      await _workoutRepo.deleteWorkout(widget.workoutId);
      for (final exerciseId in affectedExerciseIds) {
        await _prRepo.recalculateForExercise(exerciseId);
      }
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteSet(String workoutExerciseId, WorkoutSet set) async {
    await _workoutRepo.deleteSet(set.id);
    final we = _workoutExercises.firstWhere((w) => w.id == workoutExerciseId);
    _touchedExerciseIds.add(we.exerciseId);
    setState(() {
      _setsByWorkoutExercise[workoutExerciseId]?.removeWhere((s) => s.id == set.id);
      _changed = true;
    });
  }

  Future<void> _updateSet(String workoutExerciseId, WorkoutSet updated) async {
    await _workoutRepo.updateSet(updated);
    final we = _workoutExercises.firstWhere((w) => w.id == workoutExerciseId);
    _touchedExerciseIds.add(we.exerciseId);
    _changed = true;
  }

  /// Recalculates PRs for every exercise touched during this screen's
  /// lifetime, then reports back to the caller whether anything changed.
  Future<bool> _finishAndPop() async {
    for (final exerciseId in _touchedExerciseIds) {
      await _prRepo.recalculateForExercise(exerciseId);
    }
    return _changed;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _workout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final workout = _workout!;
    final duration = workout.duration;

    // Total volume across all completed sets in this workout.
    double totalVolume = 0;
    int totalSets = 0;
    for (final sets in _setsByWorkoutExercise.values) {
      for (final s in sets) {
        if (s.isCompleted) {
          totalSets++;
          totalVolume += s.volume;
        }
      }
    }

    return WillPopScope(
      onWillPop: () async {
        final changed = await _finishAndPop();
        if (context.mounted) Navigator.of(context).pop(changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _rename,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(workout.name, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 14),
              ],
            ),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteWorkout),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(formatWorkoutDate(workout.startTime)),
                  if (duration != null) Text('· ${formatDuration(duration)}'),
                  Text('· $totalSets sets'),
                  Text('· ${formatNumber(totalVolume)} volume'),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final we in _workoutExercises) _ExerciseSection(
              workoutExercise: we,
              exercise: _exerciseLookup[we.exerciseId],
              sets: _setsByWorkoutExercise[we.id] ?? [],
              onDeleteSet: (set) => _deleteSet(we.id, set),
              onUpdateSet: (set) => _updateSet(we.id, set),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseSection extends StatelessWidget {
  final WorkoutExercise workoutExercise;
  final Exercise? exercise;
  final List<WorkoutSet> sets;
  final void Function(WorkoutSet) onDeleteSet;
  final void Function(WorkoutSet) onUpdateSet;

  const _ExerciseSection({
    required this.workoutExercise,
    required this.exercise,
    required this.sets,
    required this.onDeleteSet,
    required this.onUpdateSet,
  });

  @override
  Widget build(BuildContext context) {
    if (exercise == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise!.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(exercise!.equipment.label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          if (sets.isEmpty)
            const Text('No sets recorded.', style: TextStyle(color: Colors.grey))
          else
            Row(
              children: const [
                SizedBox(width: 28, child: Text('Set', style: TextStyle(fontSize: 12, color: Colors.grey))),
                Expanded(child: Text('Weight', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
                SizedBox(width: 6),
                Expanded(child: Text('Reps', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
                SizedBox(width: 44),
              ],
            ),
          for (final set in sets)
            _EditableSetRow(
              key: ValueKey(set.id),
              set: set,
              exerciseType: exercise!.type,
              onDelete: () => onDeleteSet(set),
              onUpdate: onUpdateSet,
            ),
        ],
      ),
    );
  }
}

class _EditableSetRow extends StatefulWidget {
  final WorkoutSet set;
  final ExerciseType exerciseType;
  final VoidCallback onDelete;
  final void Function(WorkoutSet) onUpdate;

  const _EditableSetRow({
    super.key,
    required this.set,
    required this.exerciseType,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_EditableSetRow> createState() => _EditableSetRowState();
}

class _EditableSetRowState extends State<_EditableSetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
        text: widget.set.weight == null ? '' : formatNumber(widget.set.weight!));
    _repsController = TextEditingController(text: widget.set.reps?.toString() ?? '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  bool get _showWeight =>
      widget.exerciseType == ExerciseType.weightReps ||
      widget.exerciseType == ExerciseType.weightedBodyweight;
  bool get _showReps =>
      widget.exerciseType == ExerciseType.weightReps ||
      widget.exerciseType == ExerciseType.bodyweightReps ||
      widget.exerciseType == ExerciseType.weightedBodyweight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('${widget.set.setNumber}', textAlign: TextAlign.center)),
          if (_showWeight)
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) {
                    widget.onUpdate(widget.set.copyWith(weight: parsed));
                  }
                },
              ),
            ),
          if (_showWeight) const SizedBox(width: 6),
          if (_showReps)
            Expanded(
              child: TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) {
                    widget.onUpdate(widget.set.copyWith(reps: parsed));
                  }
                },
              ),
            ),
          SizedBox(
            width: 44,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
