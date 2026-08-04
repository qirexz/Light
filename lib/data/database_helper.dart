import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Central access point for the app's local SQLite database.
///
/// Schema overview:
///   exercises          - the exercise library (built-in + custom)
///   workouts           - a logged training session
///   workout_exercises  - join: which exercises appeared in a workout
///   sets               - individual sets performed (the core data unit)
///   routines           - saved workout templates
///   routine_exercises  - join: which exercises + targets belong to a routine
///   measurements       - body measurement entries over time
///   personal_records   - cached best-ever stats per exercise
///
/// All history tables are unbounded by design: no pruning, no default
/// time filters baked into the schema. Anything that limits a graph to
/// "last 3 months" etc. is a UI-layer choice made later, not a DB one.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gym_tracker.db');

    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Enforce foreign key constraints (off by default in sqflite).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        primary_muscle TEXT NOT NULL,
        secondary_muscles TEXT,
        equipment TEXT NOT NULL,
        type TEXT NOT NULL,
        instructions TEXT,
        is_custom INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        notes TEXT,
        routine_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercises (
        id TEXT PRIMARY KEY,
        workout_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        notes TEXT,
        superset_group_id TEXT,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE sets (
        id TEXT PRIMARY KEY,
        workout_exercise_id TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        weight REAL,
        reps INTEGER,
        rpe REAL,
        duration_seconds INTEGER,
        distance REAL,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercises (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE routines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE routine_exercises (
        id TEXT PRIMARY KEY,
        routine_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        target_sets INTEGER NOT NULL DEFAULT 3,
        target_reps INTEGER,
        target_weight REAL,
        notes TEXT,
        superset_group_id TEXT,
        FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        date TEXT NOT NULL,
        photo_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE personal_records (
        id TEXT PRIMARY KEY,
        exercise_id TEXT NOT NULL,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        achieved_at TEXT NOT NULL,
        workout_set_id TEXT NOT NULL,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE,
        UNIQUE (exercise_id, type)
      )
    ''');

    // Indexes to keep unlimited-history queries (graphs, PR lookups,
    // "all sets ever done for exercise X") fast as the dataset grows.
    await db.execute(
        'CREATE INDEX idx_workouts_start_time ON workouts (start_time)');
    await db.execute(
        'CREATE INDEX idx_workout_exercises_workout ON workout_exercises (workout_id)');
    await db.execute(
        'CREATE INDEX idx_workout_exercises_exercise ON workout_exercises (exercise_id)');
    await db.execute(
        'CREATE INDEX idx_sets_workout_exercise ON sets (workout_exercise_id)');
    await db.execute(
        'CREATE INDEX idx_routine_exercises_routine ON routine_exercises (routine_id)');
    await db.execute(
        'CREATE INDEX idx_measurements_type_date ON measurements (type, date)');
    await db.execute(
        'CREATE INDEX idx_personal_records_exercise ON personal_records (exercise_id)');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Wipes all data but keeps the schema. Useful for a "reset app data"
  /// settings option later; not exposed in the UI yet.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sets');
      await txn.delete('workout_exercises');
      await txn.delete('workouts');
      await txn.delete('routine_exercises');
      await txn.delete('routines');
      await txn.delete('measurements');
      await txn.delete('personal_records');
      await txn.delete('exercises');
    });
  }
}
