class WorkoutSet {
  final String id;
  final String workoutExerciseId;
  final int setNumber;

  // Strength fields
  final double? weight; // in the user's chosen unit (kg or lb)
  final int? reps;
  final double? rpe; // rate of perceived exertion, 1-10

  // Cardio / duration fields
  final int? durationSeconds;
  final double? distance; // in km or mi

  final bool isWarmup;
  final bool isCompleted;

  WorkoutSet({
    required this.id,
    required this.workoutExerciseId,
    required this.setNumber,
    this.weight,
    this.reps,
    this.rpe,
    this.durationSeconds,
    this.distance,
    this.isWarmup = false,
    this.isCompleted = false,
  });

  /// Estimated one-rep max using the Epley formula.
  /// Returns null if weight or reps are missing, or reps is 0.
  double? get estimated1RM {
    if (weight == null || reps == null || reps == 0) return null;
    if (reps == 1) return weight;
    return weight! * (1 + reps! / 30.0);
  }

  /// Total volume for this set (weight x reps). 0 for bodyweight-only
  /// or duration-based sets without a weight.
  double get volume {
    if (weight == null || reps == null) return 0;
    return weight! * reps!;
  }

  WorkoutSet copyWith({
    double? weight,
    int? reps,
    double? rpe,
    int? durationSeconds,
    double? distance,
    bool? isWarmup,
    bool? isCompleted,
  }) {
    return WorkoutSet(
      id: id,
      workoutExerciseId: workoutExerciseId,
      setNumber: setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      rpe: rpe ?? this.rpe,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distance: distance ?? this.distance,
      isWarmup: isWarmup ?? this.isWarmup,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_exercise_id': workoutExerciseId,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      'rpe': rpe,
      'duration_seconds': durationSeconds,
      'distance': distance,
      'is_warmup': isWarmup ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      id: map['id'] as String,
      workoutExerciseId: map['workout_exercise_id'] as String,
      setNumber: map['set_number'] as int,
      weight: (map['weight'] as num?)?.toDouble(),
      reps: map['reps'] as int?,
      rpe: (map['rpe'] as num?)?.toDouble(),
      durationSeconds: map['duration_seconds'] as int?,
      distance: (map['distance'] as num?)?.toDouble(),
      isWarmup: (map['is_warmup'] as int) == 1,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }
}
