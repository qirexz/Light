import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../data/database_helper.dart';

/// Exports and restores all user-generated data as a single JSON
/// document: custom exercises, workouts and their sets, routines,
/// measurements, and personal records. Built-in (non-custom) exercises
/// are intentionally excluded since they're reseeded automatically and
/// including ~120 of them in every backup would just be dead weight.
///
/// Known limitation: progress photo files themselves aren't bundled
/// into the backup, only their on-device file paths - restoring on a
/// different device/install will show missing-photo entries for any
/// measurement that had one attached. Everything else round-trips
/// fully.
class BackupService {
  static const _formatVersion = 1;
  static const _tables = [
    'exercises', // filtered to is_custom = 1 on export
    'workouts',
    'workout_exercises',
    'sets',
    'routines',
    'routine_exercises',
    'measurements',
    'personal_records',
  ];

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<String> exportAll() async {
    final db = await _db;
    final data = <String, dynamic>{};
    for (final table in _tables) {
      data[table] = table == 'exercises'
          ? await db.query('exercises', where: 'is_custom = 1')
          : await db.query(table);
    }
    final envelope = {
      'format_version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'data': data,
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Restores data from a previously exported JSON string. Existing
  /// rows with matching ids are overwritten (ConflictAlgorithm.replace)
  /// - safe to re-import the same backup without creating duplicates,
  /// but importing a backup from a different install will merge rather
  /// than wipe first, so old and imported data coexist by id.
  Future<void> importAll(String jsonString) async {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const FormatException('This file doesn\'t look like a Gym Tracker backup.');
    }

    final db = await _db;
    await db.transaction((txn) async {
      for (final table in _tables) {
        final rows = data[table] as List<dynamic>?;
        if (rows == null) continue;
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(
            table,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }
}
