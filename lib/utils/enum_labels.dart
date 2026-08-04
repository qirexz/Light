import '../models/exercise.dart';
import '../models/measurement.dart';
import '../models/personal_record.dart';

extension MuscleGroupLabel on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.biceps:
        return 'Biceps';
      case MuscleGroup.triceps:
        return 'Triceps';
      case MuscleGroup.forearms:
        return 'Forearms';
      case MuscleGroup.abs:
        return 'Abs';
      case MuscleGroup.quads:
        return 'Quads';
      case MuscleGroup.hamstrings:
        return 'Hamstrings';
      case MuscleGroup.glutes:
        return 'Glutes';
      case MuscleGroup.calves:
        return 'Calves';
      case MuscleGroup.fullBody:
        return 'Full Body';
      case MuscleGroup.cardio:
        return 'Cardio';
      case MuscleGroup.other:
        return 'Other';
    }
  }
}

extension EquipmentLabel on Equipment {
  String get label {
    switch (this) {
      case Equipment.barbell:
        return 'Barbell';
      case Equipment.dumbbell:
        return 'Dumbbell';
      case Equipment.machine:
        return 'Machine';
      case Equipment.cable:
        return 'Cable';
      case Equipment.bodyweight:
        return 'Bodyweight';
      case Equipment.kettlebell:
        return 'Kettlebell';
      case Equipment.band:
        return 'Band';
      case Equipment.plate:
        return 'Plate';
      case Equipment.other:
        return 'Other';
    }
  }
}

extension ExerciseTypeLabel on ExerciseType {
  String get label {
    switch (this) {
      case ExerciseType.weightReps:
        return 'Weight & Reps';
      case ExerciseType.bodyweightReps:
        return 'Bodyweight';
      case ExerciseType.weightedBodyweight:
        return 'Weighted Bodyweight';
      case ExerciseType.duration:
        return 'Duration';
      case ExerciseType.cardio:
        return 'Cardio';
    }
  }
}

extension MeasurementTypeLabel on MeasurementType {
  String get label {
    switch (this) {
      case MeasurementType.bodyWeight:
        return 'Body Weight';
      case MeasurementType.bodyFatPercent:
        return 'Body Fat %';
      case MeasurementType.neck:
        return 'Neck';
      case MeasurementType.shoulders:
        return 'Shoulders';
      case MeasurementType.chest:
        return 'Chest';
      case MeasurementType.waist:
        return 'Waist';
      case MeasurementType.hips:
        return 'Hips';
      case MeasurementType.bicepLeft:
        return 'Bicep (L)';
      case MeasurementType.bicepRight:
        return 'Bicep (R)';
      case MeasurementType.forearmLeft:
        return 'Forearm (L)';
      case MeasurementType.forearmRight:
        return 'Forearm (R)';
      case MeasurementType.thighLeft:
        return 'Thigh (L)';
      case MeasurementType.thighRight:
        return 'Thigh (R)';
      case MeasurementType.calfLeft:
        return 'Calf (L)';
      case MeasurementType.calfRight:
        return 'Calf (R)';
    }
  }

  /// Default unit used when logging a new entry of this type. Weight
  /// uses kg, body fat uses %, and every circumference measurement
  /// uses cm - all editable per-entry if the user wants a different
  /// unit for a specific reading.
  String get defaultUnit {
    switch (this) {
      case MeasurementType.bodyWeight:
        return 'kg';
      case MeasurementType.bodyFatPercent:
        return '%';
      default:
        return 'cm';
    }
  }
}

extension RecordTypeLabel on RecordType {
  String get label {
    switch (this) {
      case RecordType.heaviestWeight:
        return 'Heaviest Weight';
      case RecordType.best1RM:
        return 'Best Est. 1RM';
      case RecordType.bestVolume:
        return 'Best Set Volume';
      case RecordType.bestReps:
        return 'Most Reps';
      case RecordType.bestDuration:
        return 'Longest Duration';
      case RecordType.bestDistance:
        return 'Longest Distance';
    }
  }

  String get shortLabel {
    switch (this) {
      case RecordType.heaviestWeight:
        return 'Heaviest';
      case RecordType.best1RM:
        return 'Best 1RM';
      case RecordType.bestVolume:
        return 'Best Volume';
      case RecordType.bestReps:
        return 'Most Reps';
      case RecordType.bestDuration:
        return 'Longest';
      case RecordType.bestDistance:
        return 'Farthest';
    }
  }
}
