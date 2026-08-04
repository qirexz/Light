import '../models/exercise.dart';

enum GraphMetric { weight, oneRm, volume, reps, duration, distance }

extension GraphMetricLabel on GraphMetric {
  String get label {
    switch (this) {
      case GraphMetric.weight:
        return 'Best Weight';
      case GraphMetric.oneRm:
        return 'Est. 1RM';
      case GraphMetric.volume:
        return 'Session Volume';
      case GraphMetric.reps:
        return 'Best Reps';
      case GraphMetric.duration:
        return 'Duration';
      case GraphMetric.distance:
        return 'Distance';
    }
  }
}

/// Which graph metrics make sense for a given exercise's tracking
/// style - no point offering a "Best Weight" graph for a bodyweight
/// plank.
List<GraphMetric> graphMetricsForExerciseType(ExerciseType type) {
  switch (type) {
    case ExerciseType.weightReps:
    case ExerciseType.weightedBodyweight:
      return [GraphMetric.weight, GraphMetric.oneRm, GraphMetric.volume, GraphMetric.reps];
    case ExerciseType.bodyweightReps:
      return [GraphMetric.reps];
    case ExerciseType.duration:
      return [GraphMetric.duration];
    case ExerciseType.cardio:
      return [GraphMetric.duration, GraphMetric.distance];
  }
}

class SessionPoint {
  final DateTime date;
  final double value;
  const SessionPoint({required this.date, required this.value});
}

/// Aggregates raw set-history rows (as returned by
/// WorkoutRepository.getFullSetHistoryForExercise) into one point per
/// workout session for the requested metric. No time-window filtering
/// happens here - every session ever logged is included, which is what
/// makes the resulting graph "unlimited history" by default.
List<SessionPoint> computeSessionPoints(
  List<Map<String, dynamic>> history,
  GraphMetric metric,
) {
  final byWorkout = <String, List<Map<String, dynamic>>>{};
  for (final row in history) {
    byWorkout.putIfAbsent(row['workout_id'] as String, () => []).add(row);
  }

  final points = <SessionPoint>[];
  for (final rows in byWorkout.values) {
    final date = DateTime.parse(rows.first['workout_date'] as String);
    double? value;

    switch (metric) {
      case GraphMetric.weight:
        for (final r in rows) {
          final w = (r['weight'] as num?)?.toDouble();
          if (w != null && (value == null || w > value)) value = w;
        }
        break;
      case GraphMetric.oneRm:
        for (final r in rows) {
          final w = (r['weight'] as num?)?.toDouble();
          final reps = r['reps'] as int?;
          if (w != null && w > 0 && reps != null && reps > 0) {
            final rm = reps == 1 ? w : w * (1 + reps / 30.0);
            if (value == null || rm > value) value = rm;
          }
        }
        break;
      case GraphMetric.volume:
        value = 0;
        for (final r in rows) {
          final w = (r['weight'] as num?)?.toDouble();
          final reps = r['reps'] as int?;
          if (w != null && reps != null) value = value! + (w * reps);
        }
        break;
      case GraphMetric.reps:
        for (final r in rows) {
          final reps = r['reps'] as int?;
          if (reps != null && (value == null || reps > value)) value = reps.toDouble();
        }
        break;
      case GraphMetric.duration:
        for (final r in rows) {
          final d = r['duration_seconds'] as int?;
          if (d != null && (value == null || d > value)) value = d.toDouble();
        }
        break;
      case GraphMetric.distance:
        for (final r in rows) {
          final d = (r['distance'] as num?)?.toDouble();
          if (d != null && (value == null || d > value)) value = d;
        }
        break;
    }

    if (value != null && value > 0) {
      points.add(SessionPoint(date: date, value: value));
    }
  }

  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}
