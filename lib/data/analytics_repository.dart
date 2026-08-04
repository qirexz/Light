import 'package:sqflite/sqflite.dart';
import '../models/exercise.dart';
import 'database_helper.dart';

class OverallStats {
  final int workoutCount;
  final int totalSets;
  final double totalVolume;
  final DateTime? firstWorkoutDate;

  const OverallStats({
    required this.workoutCount,
    required this.totalSets,
    required this.totalVolume,
    required this.firstWorkoutDate,
  });

  /// Average workouts per week since the first-ever logged workout.
  /// Returns 0 if there's no history yet.
  double get avgWorkoutsPerWeek {
    if (firstWorkoutDate == null || workoutCount == 0) return 0;
    final weeks = DateTime.now().difference(firstWorkoutDate!).inDays / 7;
    if (weeks < 1) return workoutCount.toDouble();
    return workoutCount / weeks;
  }
}

class WeeklyVolumePoint {
  final DateTime weekStart;
  final double volume;
  const WeeklyVolumePoint({required this.weekStart, required this.volume});
}

class MuscleGroupCount {
  final MuscleGroup muscle;
  final int setCount;
  const MuscleGroupCount({required this.muscle, required this.setCount});
}

class TopExercise {
  final String exerciseId;
  final String name;
  final int setCount;
  const TopExercise({required this.exerciseId, required this.name, required this.setCount});
}

/// Dashboard-level analytics computed with SQL aggregation rather than
/// loading raw rows into Dart, so the numbers stay fast to compute no
/// matter how many years of unlimited history the user has logged.
class AnalyticsRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<OverallStats> getOverallStats() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT w.id) as workout_count,
        SUM(CASE WHEN s.is_completed = 1 THEN 1 ELSE 0 END) as total_sets,
        SUM(CASE WHEN s.is_completed = 1 THEN COALESCE(s.weight, 0) * COALESCE(s.reps, 0) ELSE 0 END) as total_volume,
        MIN(w.start_time) as first_workout
      FROM workouts w
      LEFT JOIN workout_exercises we ON we.workout_id = w.id
      LEFT JOIN sets s ON s.workout_exercise_id = we.id
    ''');
    final r = rows.first;
    final firstWorkout = r['first_workout'] as String?;
    return OverallStats(
      workoutCount: r['workout_count'] as int? ?? 0,
      totalSets: r['total_sets'] as int? ?? 0,
      totalVolume: (r['total_volume'] as num?)?.toDouble() ?? 0,
      firstWorkoutDate: firstWorkout == null ? null : DateTime.parse(firstWorkout),
    );
  }

  /// Total training volume bucketed by ISO week, across all of history
  /// (no time-window cutoff). Weeks with zero logged volume are simply
  /// absent from the result rather than padded in - the chart widget
  /// decides how to render gaps.
  Future<List<WeeklyVolumePoint>> getWeeklyVolume() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        strftime('%Y-%W', w.start_time) as week_key,
        MIN(w.start_time) as week_start_sample,
        SUM(CASE WHEN s.is_completed = 1 THEN COALESCE(s.weight, 0) * COALESCE(s.reps, 0) ELSE 0 END) as volume
      FROM workouts w
      JOIN workout_exercises we ON we.workout_id = w.id
      JOIN sets s ON s.workout_exercise_id = we.id
      GROUP BY week_key
      ORDER BY week_key ASC
    ''');
    return rows
        .map((r) => WeeklyVolumePoint(
              weekStart: DateTime.parse(r['week_start_sample'] as String),
              volume: (r['volume'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  /// Completed sets per primary muscle group across all history, for
  /// the muscle-balance chart.
  Future<List<MuscleGroupCount>> getMuscleGroupSetCounts() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT e.primary_muscle as muscle, COUNT(*) as count
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      JOIN exercises e ON we.exercise_id = e.id
      WHERE s.is_completed = 1
      GROUP BY e.primary_muscle
      ORDER BY count DESC
    ''');
    return rows.map((r) {
      final muscle = MuscleGroup.values.firstWhere(
        (m) => m.name == r['muscle'] as String,
        orElse: () => MuscleGroup.other,
      );
      return MuscleGroupCount(muscle: muscle, setCount: r['count'] as int? ?? 0);
    }).toList();
  }

  /// The exercises trained most often by completed set count, all-time.
  Future<List<TopExercise>> getTopExercises({int limit = 8}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT e.id as exercise_id, e.name as name, COUNT(*) as set_count
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      JOIN exercises e ON we.exercise_id = e.id
      WHERE s.is_completed = 1
      GROUP BY e.id
      ORDER BY set_count DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((r) => TopExercise(
              exerciseId: r['exercise_id'] as String,
              name: r['name'] as String,
              setCount: r['set_count'] as int? ?? 0,
            ))
        .toList();
  }
}
