class Workout {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final String? notes;
  final String? routineId; // if started from a routine template

  Workout({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    this.notes,
    this.routineId,
  });

  Duration? get duration =>
      endTime == null ? null : endTime!.difference(startTime);

  Workout copyWith({
    String? name,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
  }) {
    return Workout(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      routineId: routineId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'notes': notes,
      'routine_id': routineId,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as String,
      name: map['name'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] == null
          ? null
          : DateTime.parse(map['end_time'] as String),
      notes: map['notes'] as String?,
      routineId: map['routine_id'] as String?,
    );
  }
}
