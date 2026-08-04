import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/notification_service.dart';
import '../data/personal_record_repository.dart';
import '../data/workout_repository.dart';
import '../models/exercise.dart';
import '../models/personal_record.dart';
import '../models/routine_exercise.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';

/// Result of finishing a workout: the saved workout plus any personal
/// records that were newly set, each paired with the exercise name so
/// the UI can show a "New PR!" summary without extra lookups.
class FinishWorkoutResult {
  final Workout workout;
  final List<NewRecordInfo> newRecords;
  FinishWorkoutResult({required this.workout, required this.newRecords});
}

class NewRecordInfo {
  final String exerciseName;
  final PersonalRecord record;
  NewRecordInfo({required this.exerciseName, required this.record});
}

/// One exercise "block" within the workout currently being logged, plus
/// the sets performed for it so far. This is the in-memory counterpart
/// to the WorkoutExercise + sets rows that get written to the database
/// only when the workout is finished.
class ActiveExercise {
  final String id; // doubles as the eventual workout_exercise_id
  final Exercise exercise;
  final List<WorkoutSet> sets;
  String? notes;
  String? supersetGroupId;

  ActiveExercise({
    required this.id,
    required this.exercise,
    List<WorkoutSet>? sets,
    this.supersetGroupId,
  }) : sets = sets ?? [];
}

/// Owns the state of the workout currently being logged: which
/// exercises and sets have been added, elapsed time, and the rest
/// timer. Lives above the navigator (via Provider) so the user can
/// navigate to the exercise picker and back without losing progress.
class ActiveWorkoutManager extends ChangeNotifier {
  final WorkoutRepository _workoutRepo = WorkoutRepository();
  final PersonalRecordRepository _prRepo = PersonalRecordRepository();
  final _uuid = const Uuid();

  Workout? _workout;
  final List<ActiveExercise> _exercises = [];

  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _restTotalSeconds = 0;

  Workout? get workout => _workout;
  List<ActiveExercise> get exercises => List.unmodifiable(_exercises);
  bool get isActive => _workout != null;
  bool get isResting => _restTimer != null && _restSecondsRemaining > 0;
  int get restSecondsRemaining => _restSecondsRemaining;
  int get restTotalSeconds => _restTotalSeconds;

  int get totalCompletedSets =>
      _exercises.fold(0, (sum, e) => sum + e.sets.where((s) => s.isCompleted).length);

  // ---------------- Workout lifecycle ----------------

  void startWorkout({String name = 'Workout'}) {
    _workout = Workout(id: _uuid.v4(), name: name, startTime: DateTime.now());
    _exercises.clear();
    notifyListeners();
  }

  /// Starts a new workout pre-populated from a routine template: one
  /// ActiveExercise per routine exercise, with `targetSets` empty sets
  /// created upfront (pre-filled with the target weight/reps as a
  /// suggestion, not yet marked complete) and superset groupings
  /// carried over.
  void startWorkoutFromRoutine({
    required String routineName,
    required String routineId,
    required List<RoutineExercise> routineExercises,
    required Map<String, Exercise> exerciseLookup,
  }) {
    _workout = Workout(
      id: _uuid.v4(),
      name: routineName,
      startTime: DateTime.now(),
      routineId: routineId,
    );
    _exercises.clear();

    final sorted = [...routineExercises]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    for (final re in sorted) {
      final exercise = exerciseLookup[re.exerciseId];
      if (exercise == null) continue;
      final ae = ActiveExercise(
        id: _uuid.v4(),
        exercise: exercise,
        supersetGroupId: re.supersetGroupId,
      );
      for (var i = 0; i < re.targetSets; i++) {
        ae.sets.add(WorkoutSet(
          id: _uuid.v4(),
          workoutExerciseId: ae.id,
          setNumber: i + 1,
          weight: re.targetWeight,
          reps: re.targetReps,
        ));
      }
      _exercises.add(ae);
    }
    notifyListeners();
  }

  void renameWorkout(String name) {
    if (_workout == null) return;
    _workout = _workout!.copyWith(name: name);
    notifyListeners();
  }

  /// Persists the workout, its exercises, and its sets to the database,
  /// checks each completed set against personal records, then clears
  /// the in-memory state. Sets with no data entered at all (never
  /// touched) are dropped rather than saved as empty rows.
  Future<FinishWorkoutResult?> finishWorkout({String? notes}) async {
    if (_workout == null) return null;
    final finished = _workout!.copyWith(endTime: DateTime.now(), notes: notes);
    await _workoutRepo.insertWorkout(finished);

    final newRecords = <NewRecordInfo>[];

    for (var i = 0; i < _exercises.length; i++) {
      final ae = _exercises[i];
      final we = WorkoutExercise(
        id: ae.id,
        workoutId: finished.id,
        exerciseId: ae.exercise.id,
        orderIndex: i,
        notes: ae.notes,
        supersetGroupId: ae.supersetGroupId,
      );
      await _workoutRepo.insertWorkoutExercise(we);

      for (final set in ae.sets) {
        final isEmpty = set.weight == null &&
            set.reps == null &&
            set.durationSeconds == null &&
            set.distance == null;
        if (isEmpty) continue;
        await _workoutRepo.insertSet(set);

        final records = await _prRepo.checkSetForRecords(
          exerciseId: ae.exercise.id,
          set: set,
          achievedAt: finished.startTime,
        );
        for (final r in records) {
          newRecords.add(NewRecordInfo(exerciseName: ae.exercise.name, record: r));
        }
      }
    }

    _reset();
    notifyListeners();
    return FinishWorkoutResult(workout: finished, newRecords: newRecords);
  }

  /// Abandons the workout in progress without saving anything.
  void discardWorkout() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    _workout = null;
    _exercises.clear();
    _stopRestTimer();
  }

  // ---------------- Exercises ----------------

  void addExercise(Exercise exercise) {
    _exercises.add(ActiveExercise(id: _uuid.v4(), exercise: exercise));
    notifyListeners();
  }

  void removeExercise(String activeExerciseId) {
    _exercises.removeWhere((e) => e.id == activeExerciseId);
    notifyListeners();
  }

  void reorderExercises(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _exercises.removeAt(oldIndex);
    _exercises.insert(newIndex, item);
    notifyListeners();
  }

  /// Toggles whether the exercise at [index] is linked with the one
  /// directly after it as a superset (same pattern as the routine
  /// builder, applied live during a workout).
  void toggleSupersetWithNext(int index) {
    if (index < 0 || index >= _exercises.length - 1) return;
    final a = _exercises[index];
    final b = _exercises[index + 1];
    if (a.supersetGroupId != null && a.supersetGroupId == b.supersetGroupId) {
      a.supersetGroupId = null;
      b.supersetGroupId = null;
    } else {
      final groupId = a.supersetGroupId ?? _uuid.v4();
      a.supersetGroupId = groupId;
      b.supersetGroupId = groupId;
    }
    notifyListeners();
  }

  // ---------------- Sets ----------------

  ActiveExercise _findExercise(String activeExerciseId) =>
      _exercises.firstWhere((e) => e.id == activeExerciseId);

  /// Adds a new set, pre-filling weight/reps from the previous set in
  /// the same exercise as a convenience (matches the common pattern of
  /// repeating the same load across sets).
  void addSet(String activeExerciseId) {
    final ae = _findExercise(activeExerciseId);
    final previous = ae.sets.isNotEmpty ? ae.sets.last : null;
    ae.sets.add(WorkoutSet(
      id: _uuid.v4(),
      workoutExerciseId: activeExerciseId,
      setNumber: ae.sets.length + 1,
      weight: previous?.weight,
      reps: previous?.reps,
    ));
    notifyListeners();
  }

  void removeSet(String activeExerciseId, String setId) {
    final ae = _findExercise(activeExerciseId);
    ae.sets.removeWhere((s) => s.id == setId);
    // Renumber remaining sets so set_number stays contiguous.
    for (var i = 0; i < ae.sets.length; i++) {
      final s = ae.sets[i];
      ae.sets[i] = WorkoutSet(
        id: s.id,
        workoutExerciseId: activeExerciseId,
        setNumber: i + 1,
        weight: s.weight,
        reps: s.reps,
        rpe: s.rpe,
        durationSeconds: s.durationSeconds,
        distance: s.distance,
        isWarmup: s.isWarmup,
        isCompleted: s.isCompleted,
      );
    }
    notifyListeners();
  }

  void updateSet(
    String activeExerciseId,
    String setId, {
    double? weight,
    int? reps,
    double? rpe,
    int? durationSeconds,
    double? distance,
    bool? isWarmup,
  }) {
    final ae = _findExercise(activeExerciseId);
    final index = ae.sets.indexWhere((s) => s.id == setId);
    if (index == -1) return;
    ae.sets[index] = ae.sets[index].copyWith(
      weight: weight,
      reps: reps,
      rpe: rpe,
      durationSeconds: durationSeconds,
      distance: distance,
      isWarmup: isWarmup,
    );
    notifyListeners();
  }

  /// Toggles a set's completed state. Marking a set complete
  /// automatically kicks off the rest timer.
  void toggleSetComplete(String activeExerciseId, String setId,
      {int defaultRestSeconds = 90}) {
    final ae = _findExercise(activeExerciseId);
    final index = ae.sets.indexWhere((s) => s.id == setId);
    if (index == -1) return;
    final nowCompleted = !ae.sets[index].isCompleted;
    ae.sets[index] = ae.sets[index].copyWith(isCompleted: nowCompleted);
    if (nowCompleted) {
      startRestTimer(defaultRestSeconds);
    }
    notifyListeners();
  }

  // ---------------- Rest timer ----------------

  void startRestTimer(int seconds) {
    _stopRestTimer();
    _restTotalSeconds = seconds;
    _restSecondsRemaining = seconds;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _restSecondsRemaining -= 1;
      if (_restSecondsRemaining <= 0) {
        _stopRestTimer();
      }
      notifyListeners();
    });
    // Fire-and-forget: alerts the user even if they background the
    // app during rest. Purely additive - the in-app bar above is the
    // source of truth either way.
    NotificationService.instance.scheduleRestTimerDone(seconds);
    notifyListeners();
  }

  void addRestSeconds(int delta) {
    if (_restTimer == null) return;
    _restSecondsRemaining = (_restSecondsRemaining + delta).clamp(0, 3600);
    NotificationService.instance.scheduleRestTimerDone(_restSecondsRemaining);
    notifyListeners();
  }

  void skipRest() {
    _stopRestTimer();
    notifyListeners();
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    _restSecondsRemaining = 0;
    NotificationService.instance.cancelRestTimerNotification();
  }

  @override
  void dispose() {
    _stopRestTimer();
    super.dispose();
  }
}
