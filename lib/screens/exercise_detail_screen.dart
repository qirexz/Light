import 'package:flutter/material.dart';
import '../data/personal_record_repository.dart';
import '../data/workout_repository.dart';
import '../models/exercise.dart';
import '../models/personal_record.dart';
import '../utils/enum_labels.dart';
import '../utils/exercise_analytics.dart';
import '../utils/format_utils.dart';
import '../widgets/progress_line_chart.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final _prRepo = PersonalRecordRepository();
  final _workoutRepo = WorkoutRepository();

  Map<RecordType, PersonalRecord> _records = {};
  List<Map<String, dynamic>> _history = []; // unlimited - full history, oldest first
  bool _loading = true;
  GraphMetric? _selectedMetric;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _prRepo.getRecordsForExercise(widget.exercise.id);
    final history = await _workoutRepo.getFullSetHistoryForExercise(widget.exercise.id);
    if (!mounted) return;
    setState(() {
      _records = records;
      _history = history;
      _selectedMetric ??= graphMetricsForExerciseType(widget.exercise.type).first;
      _loading = false;
    });
  }

  /// The record types relevant to this exercise's tracking style, so we
  /// don't show a "Best Duration" tile for a barbell squat.
  List<RecordType> get _relevantTypes {
    switch (widget.exercise.type) {
      case ExerciseType.weightReps:
      case ExerciseType.weightedBodyweight:
        return [RecordType.heaviestWeight, RecordType.best1RM, RecordType.bestVolume, RecordType.bestReps];
      case ExerciseType.bodyweightReps:
        return [RecordType.bestReps];
      case ExerciseType.duration:
        return [RecordType.bestDuration];
      case ExerciseType.cardio:
        return [RecordType.bestDuration, RecordType.bestDistance];
    }
  }

  String _formatRecordValue(RecordType type, double value) {
    switch (type) {
      case RecordType.bestDuration:
        final m = (value ~/ 60);
        final s = (value % 60).toInt();
        return '$m:${s.toString().padLeft(2, '0')}';
      case RecordType.bestReps:
        return '${value.toInt()} reps';
      default:
        return formatNumber(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(exercise.primaryMuscle.label)),
                    ...exercise.secondaryMuscles.map(
                        (m) => Chip(label: Text(m.label), visualDensity: VisualDensity.compact)),
                    Chip(
                      label: Text(exercise.equipment.label),
                      avatar: const Icon(Icons.fitness_center, size: 16),
                    ),
                    Chip(
                      label: Text(exercise.type.label),
                      avatar: const Icon(Icons.bar_chart, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (exercise.instructions != null) ...[
                  const Text('Instructions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(exercise.instructions!),
                  const SizedBox(height: 24),
                ],
                const Text('Personal Records',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_records.isEmpty)
                  const Text(
                    'No records yet - log a completed set for this exercise to start tracking PRs.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final type in _relevantTypes)
                        if (_records[type] != null)
                          _PrTile(
                            label: type.label,
                            value: _formatRecordValue(type, _records[type]!.value),
                            date: _records[type]!.achievedAt,
                          ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text('Progress', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final metric in graphMetricsForExerciseType(exercise.type))
                      ChoiceChip(
                        label: Text(metric.label),
                        selected: _selectedMetric == metric,
                        onSelected: (_) => setState(() => _selectedMetric = metric),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ProgressLineChart(
                  points: computeSessionPoints(_history, _selectedMetric!),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Every session ever logged, no time limit.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 24),
                Text('History (${_history.length} sets)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  const Text(
                    'Your set-by-set history for this exercise will appear here, with no limit on how far back it goes.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ...[for (final row in _history.reversed.take(20)) _HistoryRow(row: row, exerciseType: exercise.type)],
                if (_history.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing the 20 most recent sets of ${_history.length} total.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PrTile extends StatelessWidget {
  final String label;
  final String value;
  final DateTime date;

  const _PrTile({required this.label, required this.value, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(formatShortDate(date), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final ExerciseType exerciseType;

  const _HistoryRow({required this.row, required this.exerciseType});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(row['workout_date'] as String);
    final weight = (row['weight'] as num?)?.toDouble();
    final reps = row['reps'] as int?;
    final parts = <String>[];
    if (weight != null) parts.add(formatNumber(weight));
    if (reps != null) parts.add('$reps reps');
    final durationSeconds = row['duration_seconds'] as int?;
    if (durationSeconds != null) {
      parts.add('${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(formatShortDate(date), style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(parts.join(' × '))),
        ],
      ),
    );
  }
}
