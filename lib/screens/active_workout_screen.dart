import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/active_workout_manager.dart';
import '../state/settings_manager.dart';
import '../utils/enum_labels.dart';
import '../utils/format_utils.dart';
import '../widgets/elapsed_time_text.dart';
import '../widgets/rest_timer_bar.dart';
import '../widgets/set_row.dart';
import 'exercise_library_screen.dart';

class ActiveWorkoutScreen extends StatelessWidget {
  const ActiveWorkoutScreen({super.key});

  Future<void> _addExercise(BuildContext context) async {
    final manager = context.read<ActiveWorkoutManager>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          onSelect: (exercise) => manager.addExercise(exercise),
        ),
      ),
    );
  }

  Future<void> _renameWorkout(BuildContext context) async {
    final manager = context.read<ActiveWorkoutManager>();
    final controller = TextEditingController(text: manager.workout?.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      manager.renameWorkout(newName.trim());
    }
  }

  Future<void> _finishWorkout(BuildContext context) async {
    final manager = context.read<ActiveWorkoutManager>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: Text(
            '${manager.totalCompletedSets} set(s) completed. This will save the workout.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final result = await manager.finishWorkout();
      if (context.mounted) {
        if (result != null && result.newRecords.isNotEmpty) {
          await _showNewRecordsDialog(context, result.newRecords);
        }
        if (context.mounted) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showNewRecordsDialog(
      BuildContext context, List<NewRecordInfo> records) async {
    // Group by exercise for a cleaner summary if multiple sets from the
    // same exercise each set a record.
    final byExercise = <String, List<NewRecordInfo>>{};
    for (final r in records) {
      byExercise.putIfAbsent(r.exerciseName, () => []).add(r);
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 8),
            Text('New Personal Records!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in byExercise.entries) ...[
                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final info in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text('• ${info.record.type.label}: ${formatNumber(info.record.value)}'),
                  ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nice!'),
          ),
        ],
      ),
    );
  }

  Future<void> _discardWorkout(BuildContext context) async {
    final manager = context.read<ActiveWorkoutManager>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('This workout and all logged sets will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      manager.discardWorkout();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ActiveWorkoutManager>();
    final workout = manager.workout;

    if (workout == null) {
      // Safety fallback - shouldn't normally be reached since this
      // screen is only pushed once a workout has been started.
      return const Scaffold(body: Center(child: Text('No active workout')));
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _renameWorkout(context),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: ElapsedTimeText(startTime: workout.startTime)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Discard workout',
            onPressed: () => _discardWorkout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: manager.exercises.isEmpty
                ? _EmptyState(onAddExercise: () => _addExercise(context))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: manager.exercises.length,
                    itemBuilder: (context, index) {
                      final ae = manager.exercises[index];
                      final next = index < manager.exercises.length - 1
                          ? manager.exercises[index + 1]
                          : null;
                      final linkedWithNext = next != null &&
                          ae.supersetGroupId != null &&
                          ae.supersetGroupId == next.supersetGroupId;
                      return _ExerciseCard(
                        activeExercise: ae,
                        canLinkWithNext: next != null,
                        linkedWithNext: linkedWithNext,
                        onToggleSuperset: () =>
                            manager.toggleSupersetWithNext(index),
                      );
                    },
                  ),
          ),
          const RestTimerBar(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Exercise'),
                  onPressed: () => _addExercise(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Finish'),
                  onPressed: () => _finishWorkout(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddExercise;
  const _EmptyState({required this.onAddExercise});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text('No exercises added yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Tap "Add Exercise" below to pick from the library and start logging sets.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ActiveExercise activeExercise;
  final bool canLinkWithNext;
  final bool linkedWithNext;
  final VoidCallback onToggleSuperset;

  const _ExerciseCard({
    required this.activeExercise,
    required this.canLinkWithNext,
    required this.linkedWithNext,
    required this.onToggleSuperset,
  });

  @override
  Widget build(BuildContext context) {
    final manager = context.read<ActiveWorkoutManager>();
    final exercise = activeExercise.exercise;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: linkedWithNext
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.tertiary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(exercise.equipment.label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canLinkWithNext)
                              ListTile(
                                leading: Icon(linkedWithNext ? Icons.link_off : Icons.link),
                                title: Text(linkedWithNext
                                    ? 'Unlink superset'
                                    : 'Link with next as superset'),
                                onTap: () {
                                  onToggleSuperset();
                                  Navigator.pop(context);
                                },
                              ),
                            ListTile(
                              leading: const Icon(Icons.delete_outline, color: Colors.red),
                              title: const Text('Remove exercise'),
                              onTap: () {
                                manager.removeExercise(activeExercise.id);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (linkedWithNext)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 14, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text('Superset with next exercise',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).colorScheme.tertiary)),
                  ],
                ),
              ),
            if (activeExercise.sets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: const [
                    SizedBox(width: 28, child: Text('Set', style: TextStyle(fontSize: 12, color: Colors.grey))),
                    Expanded(child: Text('Weight', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 6),
                    Expanded(child: Text('Reps', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 80),
                  ],
                ),
              ),
            ...activeExercise.sets.map((set) => SetRow(
                  key: ValueKey(set.id),
                  set: set,
                  exerciseType: exercise.type,
                  onChanged: ({weight, reps}) => manager.updateSet(
                    activeExercise.id,
                    set.id,
                    weight: weight,
                    reps: reps,
                  ),
                  onToggleComplete: () =>
                      manager.toggleSetComplete(activeExercise.id, set.id,
                          defaultRestSeconds: context.read<SettingsManager>().defaultRestSeconds),
                  onDelete: () => manager.removeSet(activeExercise.id, set.id),
                )),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Set'),
              onPressed: () => manager.addSet(activeExercise.id),
            ),
          ],
        ),
      ),
    );
  }
}
