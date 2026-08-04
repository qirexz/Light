/// Represents one exercise "block" within a workout (e.g. "Bench Press"
/// appearing as the 2nd exercise of today's session). Holds the sets
/// performed for that exercise via the `sets` table (see WorkoutSet).
class WorkoutExercise {
  final String id;
  final String workoutId;
  final String exerciseId;
  final int orderIndex;
  final String? notes;
  final String? supersetGroupId; // sets sharing this id are a superset

  WorkoutExercise({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.orderIndex,
    this.notes,
    this.supersetGroupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'order_index': orderIndex,
      'notes': notes,
      'superset_group_id': supersetGroupId,
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] as String,
      workoutId: map['workout_id'] as String,
      exerciseId: map['exercise_id'] as String,
      orderIndex: map['order_index'] as int,
      notes: map['notes'] as String?,
      supersetGroupId: map['superset_group_id'] as String?,
    );
  }
}
