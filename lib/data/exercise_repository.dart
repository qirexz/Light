import 'package:sqflite/sqflite.dart';
import '../models/exercise.dart';
import 'database_helper.dart';
import 'exercise_seed_data.dart';

/// Data access layer for the exercise library. The library itself
/// (large seeded set of built-in exercises) is populated in Phase 2 -
/// this repository just provides the CRUD operations on top of the
/// `exercises` table defined in Phase 1.
class ExerciseRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> insertExercise(Exercise exercise) async {
    final db = await _db;
    await db.insert(
      'exercises',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertExercises(List<Exercise> exercises) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in exercises) {
      batch.insert('exercises', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await _db;
    final maps = await db.query('exercises', orderBy: 'name ASC');
    return maps.map((m) => Exercise.fromMap(m)).toList();
  }

  Future<Exercise?> getExerciseById(String id) async {
    final db = await _db;
    final maps = await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Exercise.fromMap(maps.first);
  }

  Future<List<Exercise>> searchExercises(String query) async {
    final db = await _db;
    final maps = await db.query(
      'exercises',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Exercise.fromMap(m)).toList();
  }

  Future<List<Exercise>> getExercisesByMuscle(MuscleGroup muscle) async {
    final db = await _db;
    final maps = await db.query(
      'exercises',
      where: 'primary_muscle = ?',
      whereArgs: [muscle.name],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Exercise.fromMap(m)).toList();
  }

  Future<void> deleteExercise(String id) async {
    final db = await _db;
    // Only custom exercises should ever be deleted; built-ins are
    // protected at the UI layer, but we guard here too.
    await db.delete(
      'exercises',
      where: 'id = ? AND is_custom = 1',
      whereArgs: [id],
    );
  }

  Future<int> countExercises() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM exercises');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Populates the library with the built-in exercise set on first
  /// launch. Safe to call every app start - it's a no-op once
  /// exercises already exist, so it never overwrites custom exercises
  /// or duplicates rows.
  Future<void> seedIfEmpty() async {
    final count = await countExercises();
    if (count == 0) {
      await insertExercises(builtInExercises);
    }
  }

  /// Combined search/filter query for the library browse screen.
  /// Any parameter left null is treated as "no filter" on that field.
  Future<List<Exercise>> filterExercises({
    String? query,
    MuscleGroup? muscle,
    Equipment? equipment,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (query != null && query.trim().isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%${query.trim()}%');
    }
    if (muscle != null) {
      where.add('primary_muscle = ?');
      args.add(muscle.name);
    }
    if (equipment != null) {
      where.add('equipment = ?');
      args.add(equipment.name);
    }

    final maps = await db.query(
      'exercises',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return maps.map((m) => Exercise.fromMap(m)).toList();
  }
}
