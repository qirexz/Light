import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/exercise_repository.dart';
import '../data/routine_repository.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/routine_exercise.dart';
import '../state/active_workout_manager.dart';
import '../utils/enum_labels.dart';
import 'active_workout_screen.dart';
import 'routine_builder_screen.dart';

class RoutineDetailScreen extends StatefulWidget {
  final Routine routine;
  const RoutineDetailScreen({super.key, required this.routine});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  final _routineRepo = RoutineRepository();
  final _exerciseRepo = ExerciseRepository();

  List<RoutineExercise> _routineExercises = [];
  Map<String, Exercise> _exerciseLookup = {};
  bool _loading = true;
  bool _edited = false; // tracked so the list screen knows to refresh

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _routineRepo.getExercisesForRoutine(widget.routine.id);
    final lookup = <String, Exercise>{};
    for (final re in res) {
      final ex = await _exerciseRepo.getExerciseById(re.exerciseId);
      if (ex != null) lookup[re.exerciseId] = ex;
    }
    if (!mounted) return;
    setState(() {
      _routineExercises = res;
      _exerciseLookup = lookup;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderScreen(
          existingRoutine: widget.routine,
          existingExercises: _routineExercises,
          exerciseLookup: _exerciseLookup,
        ),
      ),
    );
    if (saved == true) {
      _edited = true;
      _load();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text('"${widget.routine.name}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _routineRepo.deleteRoutine(widget.routine.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _startWorkout() async {
    final manager = context.read<ActiveWorkoutManager>();
    if (manager.isActive) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Workout already in progress'),
          content: const Text(
              'Starting this routine will replace your current in-progress workout.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      manager.discardWorkout();
    }

    manager.startWorkoutFromRoutine(
      routineName: widget.routine.name,
      routineId: widget.routine.id,
      routineExercises: _routineExercises,
      exerciseLookup: _exerciseLookup,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_edited);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.routine.name),
          actions: [
            IconButton(icon: const Icon(Icons.edit), onPressed: _edit),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: _routineExercises.length,
                itemBuilder: (context, index) {
                  final re = _routineExercises[index];
                  final exercise = _exerciseLookup[re.exerciseId];
                  if (exercise == null) return const SizedBox.shrink();
                  final linkedWithNext = index < _routineExercises.length - 1 &&
                      re.supersetGroupId != null &&
                      re.supersetGroupId == _routineExercises[index + 1].supersetGroupId;
                  return ListTile(
                    leading: CircleAvatar(child: Text(exercise.name.substring(0, 1))),
                    title: Text(exercise.name),
                    subtitle: Text(
                      '${re.targetSets} sets'
                      '${re.targetReps != null ? ' × ${re.targetReps} reps' : ''}'
                      '${re.targetWeight != null ? ' @ ${re.targetWeight}' : ''}'
                      '${linkedWithNext ? ' · superset with next' : ''}',
                    ),
                  );
                },
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Workout'),
              onPressed: _routineExercises.isEmpty ? null : _startWorkout,
            ),
          ),
        ),
      ),
    );
  }
}
