enum RecordType {
  heaviestWeight,
  best1RM,
  bestVolume, // best single-set volume (weight x reps)
  bestReps, // most reps at any weight
  bestDuration,
  bestDistance,
}

/// A cached "best ever" achievement for a given exercise, kept up to
/// date whenever a new set is logged. Storing these explicitly (rather
/// than recomputing from full history every time) keeps PR lookups and
/// "new PR!" notifications fast even with years of unlimited history.
class PersonalRecord {
  final String id;
  final String exerciseId;
  final RecordType type;
  final double value;
  final DateTime achievedAt;
  final String workoutSetId; // the set that achieved this record

  PersonalRecord({
    required this.id,
    required this.exerciseId,
    required this.type,
    required this.value,
    required this.achievedAt,
    required this.workoutSetId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'type': type.name,
      'value': value,
      'achieved_at': achievedAt.toIso8601String(),
      'workout_set_id': workoutSetId,
    };
  }

  factory PersonalRecord.fromMap(Map<String, dynamic> map) {
    return PersonalRecord(
      id: map['id'] as String,
      exerciseId: map['exercise_id'] as String,
      type: RecordType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RecordType.heaviestWeight,
      ),
      value: (map['value'] as num).toDouble(),
      achievedAt: DateTime.parse(map['achieved_at'] as String),
      workoutSetId: map['workout_set_id'] as String,
    );
  }
}
