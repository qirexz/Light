import 'package:flutter/material.dart';
import '../data/exercise_repository.dart';
import '../data/personal_record_repository.dart';
import '../models/exercise.dart';
import '../models/personal_record.dart';
import '../utils/enum_labels.dart';
import '../utils/format_utils.dart';
import 'exercise_detail_screen.dart';

/// Overview of every exercise that has at least one personal record,
/// each showing its best lift (preferring estimated 1RM, falling back
/// to heaviest weight or best reps depending on what the exercise
/// tracks). Tapping an entry drills into the full PR + history detail
/// on the exercise's own screen.
class PersonalRecordsScreen extends StatefulWidget {
  const PersonalRecordsScreen({super.key});

  @override
  State<PersonalRecordsScreen> createState() => _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends State<PersonalRecordsScreen> {
  final _prRepo = PersonalRecordRepository();
  final _exerciseRepo = ExerciseRepository();

  List<PersonalRecord> _headline = [];
  Map<String, Exercise> _exerciseLookup = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final headline = await _prRepo.getAllBest1RMOrFallback();
    final lookup = <String, Exercise>{};
    for (final r in headline) {
      final ex = await _exerciseRepo.getExerciseById(r.exerciseId);
      if (ex != null) lookup[r.exerciseId] = ex;
    }
    // Sort alphabetically by exercise name for easy scanning.
    headline.sort((a, b) {
      final nameA = lookup[a.exerciseId]?.name ?? '';
      final nameB = lookup[b.exerciseId]?.name ?? '';
      return nameA.compareTo(nameB);
    });
    if (!mounted) return;
    setState(() {
      _headline = headline;
      _exerciseLookup = lookup;
      _loading = false;
    });
  }

  String _formatValue(RecordType type, double value) {
    if (type == RecordType.bestReps) return '${value.toInt()} reps';
    return formatNumber(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Records')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _headline.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        const Text('No records yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Complete some sets in a workout and your best lifts will show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _headline.length,
                  itemBuilder: (context, index) {
                    final record = _headline[index];
                    final exercise = _exerciseLookup[record.exerciseId];
                    if (exercise == null) return const SizedBox.shrink();
                    return ListTile(
                      leading: const Icon(Icons.emoji_events, color: Colors.amber),
                      title: Text(exercise.name),
                      subtitle: Text('${record.type.label} · ${formatShortDate(record.achievedAt)}'),
                      trailing: Text(
                        _formatValue(record.type, record.value),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailScreen(exercise: exercise),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
