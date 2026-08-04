import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/personal_record.dart';
import '../models/workout_set.dart';
import 'database_helper.dart';
import 'workout_repository.dart';

/// Data access layer for personal records (cached "best ever" stats per
/// exercise). Two ways records get updated:
///
/// 1. Incrementally, via [upsertIfBetter], called for each completed
///    set right after a workout is saved. Fast - no full history scan.
/// 2. By full recalculation, via [recalculateForExercise], which
///    rescans every set ever logged for an exercise. Used after past
///    sets are edited or deleted, since an edit could invalidate a
///    record that isn't the one being touched (e.g. deleting the set
///    that held the heaviest-weight record should reveal the next
///    best one, not just remove the record).
class PersonalRecordRepository {
  final _uuid = const Uuid();
  final WorkoutRepository _workoutRepo = WorkoutRepository();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<PersonalRecord?> getRecord(String exerciseId, RecordType type) async {
    final db = await _db;
    final maps = await db.query(
      'personal_records',
      where: 'exercise_id = ? AND type = ?',
      whereArgs: [exerciseId, type.name],
    );
    if (maps.isEmpty) return null;
    return PersonalRecord.fromMap(maps.first);
  }

  /// All records for one exercise, keyed by type, for easy lookup in
  /// the exercise detail screen.
  Future<Map<RecordType, PersonalRecord>> getRecordsForExercise(String exerciseId) async {
    final db = await _db;
    final maps = await db.query('personal_records',
        where: 'exercise_id = ?', whereArgs: [exerciseId]);
    final records = maps.map((m) => PersonalRecord.fromMap(m)).toList();
    return {for (final r in records) r.type: r};
  }

  /// Every exercise that has at least one PR, along with its best 1RM
  /// (or heaviest weight / best reps as a fallback) - used for the PR
  /// overview screen's headline number per exercise.
  Future<List<PersonalRecord>> getAllBest1RMOrFallback() async {
    final db = await _db;
    final maps = await db.query('personal_records',
        where: 'type IN (?, ?, ?)',
        whereArgs: [
          RecordType.best1RM.name,
          RecordType.heaviestWeight.name,
          RecordType.bestReps.name,
        ]);
    final records = maps.map((m) => PersonalRecord.fromMap(m)).toList();
    // Prefer best1RM per exercise; fall back to heaviestWeight, then bestReps.
    final byExercise = <String, PersonalRecord>{};
    for (final r in records) {
      final existing = byExercise[r.exerciseId];
      if (existing == null || _priority(r.type) < _priority(existing.type)) {
        byExercise[r.exerciseId] = r;
      }
    }
    return byExercise.values.toList();
  }

  int _priority(RecordType type) {
    switch (type) {
      case RecordType.best1RM:
        return 0;
      case RecordType.heaviestWeight:
        return 1;
      case RecordType.bestReps:
        return 2;
      default:
        return 3;
    }
  }

  /// Inserts or updates a record only if [value] beats the current
  /// best (or none exists yet). Returns the new PersonalRecord if this
  /// was a new record, or null if the existing one still stands.
  Future<PersonalRecord?> upsertIfBetter({
    required String exerciseId,
    required RecordType type,
    required double value,
    required DateTime achievedAt,
    required String workoutSetId,
  }) async {
    final existing = await getRecord(exerciseId, type);
    if (existing != null && existing.value >= value) return null;

    final record = PersonalRecord(
      id: existing?.id ?? _uuid.v4(),
      exerciseId: exerciseId,
      type: type,
      value: value,
      achievedAt: achievedAt,
      workoutSetId: workoutSetId,
    );
    final db = await _db;
    await db.insert('personal_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return record;
  }

  /// Checks a single completed set against all applicable record types
  /// and updates any that it beats. Returns the list of newly-set
  /// records (empty if none). Called once per completed set when a
  /// workout is finished.
  Future<List<PersonalRecord>> checkSetForRecords({
    required String exerciseId,
    required WorkoutSet set,
    required DateTime achievedAt,
  }) async {
    if (!set.isCompleted) return [];
    final newRecords = <PersonalRecord>[];

    if (set.weight != null && set.weight! > 0) {
      final r = await upsertIfBetter(
        exerciseId: exerciseId,
        type: RecordType.heaviestWeight,
        value: set.weight!,
        achievedAt: achievedAt,
        workoutSetId: set.id,
      );
      if (r != null) newRecords.add(r);
    }

    final oneRm = set.estimated1RM;
    if (oneRm != null && oneRm > 0) {
      final r = await upsertIfBetter(
        exerciseId: exerciseId,
        type: RecordType.best1RM,
        value: oneRm,
        achievedAt: achievedAt,
        workoutSetId: set.id,
      );
      if (r != null) newRecords.add(r);
    }

    if (set.volume > 0) {
      final r = await upsertIfBetter(
        exerciseId: exerciseId,
        type: RecordType.bestVolume,
        value: set.volume,
        achievedAt: achievedAt,
        workoutSetId: set.id,
      );
      if (r != null) newRecords.add(r);
    }

    if (set.reps != null && set.reps! > 0) {
      final r = await upsertIfBetter(
        exerciseId: exerciseId,
        type: RecordType.bestReps,
        value: set.reps!.toDouble(),
        achievedAt: achievedAt,
        workoutSetId: set.id,
      );
      if (r != null) newRecords.add(r);
    }

    if (set.durationSeconds != null && set.durationSeconds! > 0) {
      final r = await upsertIfBetter(
        exerciseId: exerciseId,
        type: RecordType.bestDuration,
        value: set.durationSeconds!.toDouble(),
        achievedAt: achievedAt,
        workoutSetId: set.id,
      );
      if (r != null) newRecords.add(r);
    }

    if (set.distance != null && set.distance! > 0) {
      final r = await upsertIfBetter(
        exerciseId: exerciseId,
        type: RecordType.bestDistance,
        value: set.distance!,
        achievedAt: achievedAt,
        workoutSetId: set.id,
      );
      if (r != null) newRecords.add(r);
    }

    return newRecords;
  }

  /// Fully rebuilds every record for one exercise by rescanning its
  /// entire set history. Use after edits/deletes to past sets, where
  /// an incremental check isn't enough (e.g. the record-holding set
  /// itself was deleted or lowered).
  Future<void> recalculateForExercise(String exerciseId) async {
    final history = await _workoutRepo.getFullSetHistoryForExercise(exerciseId);

    PersonalRecord? best(RecordType type, double Function(Map<String, dynamic> row) selector) {
      Map<String, dynamic>? bestRow;
      double bestValue = -1;
      for (final row in history) {
        final value = selector(row);
        if (value > bestValue) {
          bestValue = value;
          bestRow = row;
        }
      }
      if (bestRow == null || bestValue <= 0) return null;
      return PersonalRecord(
        id: _uuid.v4(),
        exerciseId: exerciseId,
        type: type,
        value: bestValue,
        achievedAt: DateTime.parse(bestRow['workout_date'] as String),
        workoutSetId: bestRow['id'] as String,
      );
    }

    double weightOf(Map<String, dynamic> r) => (r['weight'] as num?)?.toDouble() ?? 0;
    double repsOf(Map<String, dynamic> r) => ((r['reps'] as num?) ?? 0).toDouble();
    double oneRmOf(Map<String, dynamic> r) {
      final w = (r['weight'] as num?)?.toDouble();
      final reps = (r['reps'] as num?)?.toInt();
      if (w == null || reps == null || reps == 0) return 0;
      if (reps == 1) return w;
      return w * (1 + reps / 30.0);
    }

    double volumeOf(Map<String, dynamic> r) => weightOf(r) * repsOf(r);
    double durationOf(Map<String, dynamic> r) => ((r['duration_seconds'] as num?) ?? 0).toDouble();
    double distanceOf(Map<String, dynamic> r) => (r['distance'] as num?)?.toDouble() ?? 0;

    final results = <PersonalRecord>[];
    final heaviest = best(RecordType.heaviestWeight, weightOf);
    if (heaviest != null) results.add(heaviest);
    final oneRm = best(RecordType.best1RM, oneRmOf);
    if (oneRm != null) results.add(oneRm);
    final volume = best(RecordType.bestVolume, volumeOf);
    if (volume != null) results.add(volume);
    final reps = best(RecordType.bestReps, repsOf);
    if (reps != null) results.add(reps);
    final duration = best(RecordType.bestDuration, durationOf);
    if (duration != null) results.add(duration);
    final distance = best(RecordType.bestDistance, distanceOf);
    if (distance != null) results.add(distance);

    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('personal_records', where: 'exercise_id = ?', whereArgs: [exerciseId]);
      final batch = txn.batch();
      for (final r in results) {
        batch.insert('personal_records', r.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
