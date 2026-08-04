enum MeasurementType {
  bodyWeight,
  bodyFatPercent,
  neck,
  shoulders,
  chest,
  waist,
  hips,
  bicepLeft,
  bicepRight,
  forearmLeft,
  forearmRight,
  thighLeft,
  thighRight,
  calfLeft,
  calfRight,
}

class Measurement {
  final String id;
  final MeasurementType type;
  final double value;
  final String unit; // 'kg', 'lb', 'cm', 'in', '%'
  final DateTime date;
  final String? photoPath; // optional progress photo attached to this entry

  Measurement({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.date,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'value': value,
      'unit': unit,
      'date': date.toIso8601String(),
      'photo_path': photoPath,
    };
  }

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'] as String,
      type: MeasurementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MeasurementType.bodyWeight,
      ),
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String,
      date: DateTime.parse(map['date'] as String),
      photoPath: map['photo_path'] as String?,
    );
  }
}
