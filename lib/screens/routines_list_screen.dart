import 'package:flutter/material.dart';
import '../data/routine_repository.dart';
import '../models/routine.dart';
import 'routine_builder_screen.dart';
import 'routine_detail_screen.dart';

class RoutinesListScreen extends StatefulWidget {
  const RoutinesListScreen({super.key});

  @override
  State<RoutinesListScreen> createState() => _RoutinesListScreenState();
}

class _RoutinesListScreenState extends State<RoutinesListScreen> {
  final _repo = RoutineRepository();
  List<Routine> _routines = [];
  Map<String, int> _exerciseCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final routines = await _repo.getAllRoutines();
    final counts = <String, int>{};
    for (final r in routines) {
      counts[r.id] = (await _repo.getExercisesForRoutine(r.id)).length;
    }
    if (!mounted) return;
    setState(() {
      _routines = routines;
      _exerciseCounts = counts;
      _loading = false;
    });
  }

  Future<void> _createRoutine() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RoutineBuilderScreen()),
    );
    if (saved == true) _load();
  }

  Future<void> _openRoutine(Routine routine) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RoutineDetailScreen(routine: routine)),
    );
    // result true means the routine was edited or deleted - refresh either way.
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.list_alt, size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        const Text('No routines yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Build a routine to save your favorite workouts as templates you can start with one tap.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _routines.length,
                  itemBuilder: (context, index) {
                    final routine = _routines[index];
                    final count = _exerciseCounts[routine.id] ?? 0;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.list_alt)),
                      title: Text(routine.name),
                      subtitle: Text('$count exercise${count == 1 ? '' : 's'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openRoutine(routine),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoutine,
        icon: const Icon(Icons.add),
        label: const Text('New Routine'),
      ),
    );
  }
}
