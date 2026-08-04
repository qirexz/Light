import 'package:sqflite/sqflite.dart';
import '../models/routine.dart';
import '../models/routine_exercise.dart';
import 'database_helper.dart';

/// Data access layer for saved workout routines (templates) and the
/// exercise blueprints within them.
class RoutineRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ---------------- Routines ----------------

  Future<void> insertRoutine(Routine routine) async {
    final db = await _db;
    await db.insert('routines', routine.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Routine>> getAllRoutines() async {
    final db = await _db;
    final maps = await db.query('routines', orderBy: 'order_index ASC, created_at ASC');
    return maps.map((m) => Routine.fromMap(m)).toList();
  }

  Future<Routine?> getRoutineById(String id) async {
    final db = await _db;
    final maps = await db.query('routines', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Routine.fromMap(maps.first);
  }

  Future<void> deleteRoutine(String id) async {
    final db = await _db;
    // ON DELETE CASCADE removes the routine_exercises rows too.
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Routine Exercises ----------------

  Future<void> insertRoutineExercise(RoutineExercise re) async {
    final db = await _db;
    await db.insert('routine_exercises', re.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RoutineExercise>> getExercisesForRoutine(String routineId) async {
    final db = await _db;
    final maps = await db.query(
      'routine_exercises',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'order_index ASC',
    );
    return maps.map((m) => RoutineExercise.fromMap(m)).toList();
  }

  Future<void> deleteRoutineExercise(String id) async {
    final db = await _db;
    await db.delete('routine_exercises', where: 'id = ?', whereArgs: [id]);
  }

  /// Replaces all exercise blueprints for a routine in one transaction.
  /// Simpler and safer than diffing individual add/remove/reorder
  /// operations from the editor screen.
  Future<void> replaceRoutineExercises(
      String routineId, List<RoutineExercise> exercises) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('routine_exercises',
          where: 'routine_id = ?', whereArgs: [routineId]);
      final batch = txn.batch();
      for (final re in exercises) {
        batch.insert('routine_exercises', re.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
