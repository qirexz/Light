import 'package:flutter/material.dart';
import '../data/exercise_repository.dart';
import '../models/exercise.dart';
import '../utils/enum_labels.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  /// If provided, the screen acts as a picker: tapping an exercise
  /// calls this instead of opening the detail screen, then pops.
  final ValueChanged<Exercise>? onSelect;

  const ExerciseLibraryScreen({super.key, this.onSelect});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _repo = ExerciseRepository();
  final _searchController = TextEditingController();

  List<Exercise> _exercises = [];
  bool _loading = true;

  String _query = '';
  MuscleGroup? _muscleFilter;
  Equipment? _equipmentFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await _repo.filterExercises(
      query: _query,
      muscle: _muscleFilter,
      equipment: _equipmentFilter,
    );
    if (!mounted) return;
    setState(() {
      _exercises = results;
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _query = value;
    _load();
  }

  void _toggleMuscle(MuscleGroup m) {
    setState(() => _muscleFilter = _muscleFilter == m ? null : m);
    _load();
  }

  void _toggleEquipment(Equipment eq) {
    setState(() => _equipmentFilter = _equipmentFilter == eq ? null : eq);
    _load();
  }

  void _clearFilters() {
    setState(() {
      _muscleFilter = null;
      _equipmentFilter = null;
      _query = '';
      _searchController.clear();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _muscleFilter != null || _equipmentFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onSelect != null ? 'Add Exercise' : 'Exercise Library'),
        actions: [
          if (hasFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: MuscleGroup.values.map((m) {
                final selected = _muscleFilter == m;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(m.label),
                    selected: selected,
                    onSelected: (_) => _toggleMuscle(m),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: Equipment.values.map((eq) {
                final selected = _equipmentFilter == eq;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(eq.label),
                    selected: selected,
                    onSelected: (_) => _toggleEquipment(eq),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _exercises.isEmpty
                    ? const Center(child: Text('No exercises match your filters.'))
                    : ListView.builder(
                        itemCount: _exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _exercises[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                exercise.name.substring(0, 1),
                              ),
                            ),
                            title: Text(exercise.name),
                            subtitle: Text(
                                '${exercise.primaryMuscle.label} · ${exercise.equipment.label}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              if (widget.onSelect != null) {
                                widget.onSelect!(exercise);
                                Navigator.of(context).pop();
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ExerciseDetailScreen(exercise: exercise),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
