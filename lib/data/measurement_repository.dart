import 'package:sqflite/sqflite.dart';
import '../models/measurement.dart';
import 'database_helper.dart';

/// Data access layer for body measurement entries (weight, body fat,
/// circumferences, and any attached progress photo).
class MeasurementRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> insertMeasurement(Measurement measurement) async {
    final db = await _db;
    await db.insert('measurements', measurement.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMeasurement(Measurement measurement) async {
    final db = await _db;
    await db.update('measurements', measurement.toMap(),
        where: 'id = ?', whereArgs: [measurement.id]);
  }

  Future<void> deleteMeasurement(String id) async {
    final db = await _db;
    await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }

  /// Every entry for one measurement type, unlimited history, oldest
  /// first (natural order for a progress graph).
  Future<List<Measurement>> getEntriesForType(MeasurementType type) async {
    final db = await _db;
    final maps = await db.query(
      'measurements',
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'date ASC',
    );
    return maps.map((m) => Measurement.fromMap(m)).toList();
  }

  /// The most recent entry for every measurement type that has at
  /// least one logged entry, keyed by type - used for the overview
  /// screen's "latest reading" per row.
  Future<Map<MeasurementType, Measurement>> getLatestByType() async {
    final db = await _db;
    final maps = await db.query('measurements', orderBy: 'date ASC');
    final latest = <MeasurementType, Measurement>{};
    for (final m in maps) {
      final measurement = Measurement.fromMap(m);
      latest[measurement.type] = measurement; // later rows overwrite earlier ones
    }
    return latest;
  }

  /// Every measurement entry that has a progress photo attached,
  /// most recent first - backs the Progress Photos gallery.
  Future<List<Measurement>> getEntriesWithPhotos() async {
    final db = await _db;
    final maps = await db.query(
      'measurements',
      where: 'photo_path IS NOT NULL',
      orderBy: 'date DESC',
    );
    return maps.map((m) => Measurement.fromMap(m)).toList();
  }
}
