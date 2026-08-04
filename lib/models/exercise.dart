/// How an exercise is measured/logged. Determines which fields are
/// relevant when logging a set (weight+reps, duration, distance, etc.)
enum ExerciseType {
  weightReps, // e.g. Barbell Bench Press
  bodyweightReps, // e.g. Pull Up
  weightedBodyweight, // e.g. Weighted Pull Up
  duration, // e.g. Plank
  cardio, // e.g. Running (duration + distance)
}

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  abs,
  quads,
  hamstrings,
  glutes,
  calves,
  fullBody,
  cardio,
  other,
}

enum Equipment {
  barbell,
  dumbbell,
  machine,
  cable,
  bodyweight,
  kettlebell,
  band,
  plate,
  other,
}

class Exercise {
  final String id;
  final String name;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final Equipment equipment;
  final ExerciseType type;
  final String? instructions;
  final bool isCustom;

  Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    this.secondaryMuscles = const [],
    required this.equipment,
    required this.type,
    this.instructions,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'primary_muscle': primaryMuscle.name,
      'secondary_muscles': secondaryMuscles.map((m) => m.name).join(','),
      'equipment': equipment.name,
      'type': type.name,
      'instructions': instructions,
      'is_custom': isCustom ? 1 : 0,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String,
      primaryMuscle: MuscleGroup.values.firstWhere(
        (e) => e.name == map['primary_muscle'],
        orElse: () => MuscleGroup.other,
      ),
      secondaryMuscles: (map['secondary_muscles'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => MuscleGroup.values.firstWhere(
                (e) => e.name == s,
                orElse: () => MuscleGroup.other,
              ))
          .toList(),
      equipment: Equipment.values.firstWhere(
        (e) => e.name == map['equipment'],
        orElse: () => Equipment.other,
      ),
      type: ExerciseType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ExerciseType.weightReps,
      ),
      instructions: map['instructions'] as String?,
      isCustom: (map['is_custom'] as int) == 1,
    );
  }
}
