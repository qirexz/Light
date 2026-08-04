/// An exercise slot within a routine template, e.g. "Squat: 3 sets x 5
/// reps target". Actual performed sets get created fresh from this
/// blueprint each time the routine is started as a workout.
class RoutineExercise {
  final String id;
  final String routineId;
  final String exerciseId;
  final int orderIndex;
  final int targetSets;
  final int? targetReps;
  final double? targetWeight;
  final String? notes;
  final String? supersetGroupId;

  RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.orderIndex,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeight,
    this.notes,
    this.supersetGroupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'exercise_id': exerciseId,
      'order_index': orderIndex,
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_weight': targetWeight,
      'notes': notes,
      'superset_group_id': supersetGroupId,
    };
  }

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    return RoutineExercise(
      id: map['id'] as String,
      routineId: map['routine_id'] as String,
      exerciseId: map['exercise_id'] as String,
      orderIndex: map['order_index'] as int,
      targetSets: map['target_sets'] as int,
      targetReps: map['target_reps'] as int?,
      targetWeight: (map['target_weight'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      supersetGroupId: map['superset_group_id'] as String?,
    );
  }
}
