import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import 'database_helper.dart';

/// Aggregate numbers for a single workout, computed in SQL rather than
/// by loading every set into Dart. See getStatsForAllWorkouts.
class WorkoutStats {
  final int exerciseCount;
  final int completedSets;
  final double totalVolume;

  const WorkoutStats({
    required this.exerciseCount,
    required this.completedSets,
    required this.totalVolume,
  });

  static const empty = WorkoutStats(exerciseCount: 0, completedSets: 0, totalVolume: 0);
}

/// Data access layer for logged workouts: sessions, the exercises
/// performed within them, and the individual sets. Full workout
/// logging UI comes in Phase 3 - this establishes the persistence
/// operations everything else will build on.
class WorkoutRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ---------------- Workouts ----------------

  Future<void> insertWorkout(Workout workout) async {
    final db = await _db;
    await db.insert('workouts', workout.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Workout>> getAllWorkouts({int? limit}) async {
    final db = await _db;
    final maps = await db.query(
      'workouts',
      orderBy: 'start_time DESC',
      limit: limit, // null = unlimited, by design
    );
    return maps.map((m) => Workout.fromMap(m)).toList();
  }

  Future<Workout?> getWorkoutById(String id) async {
    final db = await _db;
    final maps = await db.query('workouts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Workout.fromMap(maps.first);
  }

  Future<List<Workout>> getWorkoutsInRange(DateTime start, DateTime end) async {
    final db = await _db;
    final maps = await db.query(
      'workouts',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_time DESC',
    );
    return maps.map((m) => Workout.fromMap(m)).toList();
  }

  Future<void> updateWorkout(Workout workout) async {
    final db = await _db;
    await db.update('workouts', workout.toMap(),
        where: 'id = ?', whereArgs: [workout.id]);
  }

  Future<void> deleteWorkout(String id) async {
    final db = await _db;
    // ON DELETE CASCADE handles workout_exercises + sets cleanup.
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  /// Aggregate stats (exercise count, completed sets, total volume) for
  /// every workout in one query, keyed by workout id. Used by the
  /// history list so it doesn't run N+1 queries per row - this stays
  /// fast even with years of unlimited history.
  Future<Map<String, WorkoutStats>> getStatsForAllWorkouts() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        we.workout_id as workout_id,
        COUNT(DISTINCT we.exercise_id) as exercise_count,
        SUM(CASE WHEN s.is_completed = 1 THEN 1 ELSE 0 END) as completed_sets,
        SUM(CASE WHEN s.is_completed = 1 THEN COALESCE(s.weight, 0) * COALESCE(s.reps, 0) ELSE 0 END) as total_volume
      FROM workout_exercises we
      LEFT JOIN sets s ON s.workout_exercise_id = we.id
      GROUP BY we.workout_id
    ''');
    return {
      for (final r in rows)
        r['workout_id'] as String: WorkoutStats(
          exerciseCount: r['exercise_count'] as int? ?? 0,
          completedSets: r['completed_sets'] as int? ?? 0,
          totalVolume: (r['total_volume'] as num?)?.toDouble() ?? 0,
        )
    };
  }

  // ---------------- Workout Exercises ----------------

  Future<void> insertWorkoutExercise(WorkoutExercise we) async {
    final db = await _db;
    await db.insert('workout_exercises', we.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WorkoutExercise>> getExercisesForWorkout(String workoutId) async {
    final db = await _db;
    final maps = await db.query(
      'workout_exercises',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'order_index ASC',
    );
    return maps.map((m) => WorkoutExercise.fromMap(m)).toList();
  }

  /// Every workout_exercise entry across all time for a given exercise.
  /// This is the backbone query for unlimited-history graphs and PRs:
  /// join this with `sets` to get every set ever logged for exercise X.
  Future<List<WorkoutExercise>> getHistoryForExercise(String exerciseId) async {
    final db = await _db;
    final maps = await db.query(
      'workout_exercises',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );
    return maps.map((m) => WorkoutExercise.fromMap(m)).toList();
  }

  // ---------------- Sets ----------------

  Future<void> insertSet(WorkoutSet set) async {
    final db = await _db;
    await db.insert('sets', set.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WorkoutSet>> getSetsForWorkoutExercise(
      String workoutExerciseId) async {
    final db = await _db;
    final maps = await db.query(
      'sets',
      where: 'workout_exercise_id = ?',
      whereArgs: [workoutExerciseId],
      orderBy: 'set_number ASC',
    );
    return maps.map((m) => WorkoutSet.fromMap(m)).toList();
  }

  Future<void> updateSet(WorkoutSet set) async {
    final db = await _db;
    await db.update('sets', set.toMap(), where: 'id = ?', whereArgs: [set.id]);
  }

  Future<void> deleteSet(String id) async {
    final db = await _db;
    await db.delete('sets', where: 'id = ?', whereArgs: [id]);
  }

  /// All sets ever logged for a given exercise, across all workouts and
  /// all time, joined with the workout's date. This is the query the
  /// Phase 7 analytics/graphs will be built on top of - no date
  /// filtering happens here, so history is unlimited by default.
  Future<List<Map<String, dynamic>>> getFullSetHistoryForExercise(
      String exerciseId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT s.*, w.start_time as workout_date, w.id as workout_id
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      WHERE we.exercise_id = ? AND s.is_completed = 1
      ORDER BY w.start_time ASC
    ''', [exerciseId]);
  }
}
