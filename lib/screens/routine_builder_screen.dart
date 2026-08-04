import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../data/routine_repository.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/routine_exercise.dart';
import '../utils/enum_labels.dart';
import 'exercise_library_screen.dart';

/// One row in the routine being built. Wraps the full Exercise object
/// (rather than just an id) so the UI has a name/equipment/type to
/// display without an extra lookup, plus the target set/rep/weight
/// values and optional superset group.
class _DraftExercise {
  final String id;
  final Exercise exercise;
  int targetSets;
  int? targetReps;
  double? targetWeight;
  String? supersetGroupId;

  _DraftExercise({
    required this.id,
    required this.exercise,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeight,
    this.supersetGroupId,
  });
}

class RoutineBuilderScreen extends StatefulWidget {
  final Routine? existingRoutine;
  final List<RoutineExercise>? existingExercises;
  final Map<String, Exercise>? exerciseLookup; // id -> Exercise, for edit mode

  const RoutineBuilderScreen({
    super.key,
    this.existingRoutine,
    this.existingExercises,
    this.exerciseLookup,
  });

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  final _uuid = const Uuid();
  final _repo = RoutineRepository();
  late final TextEditingController _nameController;
  late final String _routineId;
  late final DateTime _createdAt;
  final List<_DraftExercise> _drafts = [];
  bool _saving = false;

  bool get _isEditing => widget.existingRoutine != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingRoutine?.name ?? '');
    _routineId = widget.existingRoutine?.id ?? _uuid.v4();
    _createdAt = widget.existingRoutine?.createdAt ?? DateTime.now();

    if (widget.existingExercises != null && widget.exerciseLookup != null) {
      for (final re in widget.existingExercises!) {
        final exercise = widget.exerciseLookup![re.exerciseId];
        if (exercise == null) continue;
        _drafts.add(_DraftExercise(
          id: re.id,
          exercise: exercise,
          targetSets: re.targetSets,
          targetReps: re.targetReps,
          targetWeight: re.targetWeight,
          supersetGroupId: re.supersetGroupId,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          onSelect: (exercise) {
            setState(() {
              _drafts.add(_DraftExercise(id: _uuid.v4(), exercise: exercise));
            });
          },
        ),
      ),
    );
  }

  void _removeDraft(String id) {
    setState(() {
      // Clear a now-orphaned superset link if only one member remains.
      final removed = _drafts.firstWhere((d) => d.id == id);
      _drafts.removeWhere((d) => d.id == id);
      if (removed.supersetGroupId != null) {
        final remaining =
            _drafts.where((d) => d.supersetGroupId == removed.supersetGroupId).toList();
        if (remaining.length == 1) remaining.first.supersetGroupId = null;
      }
    });
  }

  /// Toggles whether this exercise and the one directly after it are
  /// linked as a superset. A simple, discoverable way to build supersets
  /// without a separate multi-select mode.
  void _toggleSupersetWithNext(int index) {
    if (index >= _drafts.length - 1) return;
    setState(() {
      final a = _drafts[index];
      final b = _drafts[index + 1];
      if (a.supersetGroupId != null && a.supersetGroupId == b.supersetGroupId) {
        // Unlink
        a.supersetGroupId = null;
        b.supersetGroupId = null;
      } else {
        final groupId = a.supersetGroupId ?? _uuid.v4();
        a.supersetGroupId = groupId;
        b.supersetGroupId = groupId;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give the routine a name first.')));
      return;
    }
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one exercise.')));
      return;
    }

    setState(() => _saving = true);
    final routine = Routine(id: _routineId, name: name, createdAt: _createdAt);
    final exercises = <RoutineExercise>[
      for (var i = 0; i < _drafts.length; i++)
        RoutineExercise(
          id: _drafts[i].id,
          routineId: _routineId,
          exerciseId: _drafts[i].exercise.id,
          orderIndex: i,
          targetSets: _drafts[i].targetSets,
          targetReps: _drafts[i].targetReps,
          targetWeight: _drafts[i].targetWeight,
          supersetGroupId: _drafts[i].supersetGroupId,
        ),
    ];

    await _repo.insertRoutine(routine);
    await _repo.replaceRoutineExercises(_routineId, exercises);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Routine' : 'New Routine'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Routine name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _drafts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Add exercises to build this routine.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: _drafts.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _drafts.removeAt(oldIndex);
                        _drafts.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final draft = _drafts[index];
                      final linkedWithNext = index < _drafts.length - 1 &&
                          draft.supersetGroupId != null &&
                          draft.supersetGroupId == _drafts[index + 1].supersetGroupId;
                      return _DraftExerciseCard(
                        key: ValueKey(draft.id),
                        draft: draft,
                        linkedWithNext: linkedWithNext,
                        canLinkWithNext: index < _drafts.length - 1,
                        onChanged: () => setState(() {}),
                        onDelete: () => _removeDraft(draft.id),
                        onToggleSuperset: () => _toggleSupersetWithNext(index),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
    );
  }
}

class _DraftExerciseCard extends StatefulWidget {
  final _DraftExercise draft;
  final bool linkedWithNext;
  final bool canLinkWithNext;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onToggleSuperset;

  const _DraftExerciseCard({
    super.key,
    required this.draft,
    required this.linkedWithNext,
    required this.canLinkWithNext,
    required this.onChanged,
    required this.onDelete,
    required this.onToggleSuperset,
  });

  @override
  State<_DraftExerciseCard> createState() => _DraftExerciseCardState();
}

class _DraftExerciseCardState extends State<_DraftExerciseCard> {
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _repsController =
        TextEditingController(text: widget.draft.targetReps?.toString() ?? '');
    _weightController = TextEditingController(
        text: widget.draft.targetWeight == null ? '' : widget.draft.targetWeight.toString());
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(draft.exercise.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${draft.exercise.primaryMuscle.label} · ${draft.exercise.equipment.label}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                const Text('Sets', style: TextStyle(color: Colors.grey)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: draft.targetSets > 1
                      ? () {
                          setState(() => draft.targetSets -= 1);
                          widget.onChanged();
                        }
                      : null,
                ),
                Text('${draft.targetSets}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() => draft.targetSets += 1);
                    widget.onChanged();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => draft.targetReps = int.tryParse(v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => draft.targetWeight = double.tryParse(v),
                  ),
                ),
              ],
            ),
          ),
          if (widget.canLinkWithNext)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                icon: Icon(
                  widget.linkedWithNext ? Icons.link : Icons.link_outlined,
                  size: 18,
                ),
                label: Text(widget.linkedWithNext
                    ? 'Linked as superset with next'
                    : 'Link with next as superset'),
                onPressed: widget.onToggleSuperset,
              ),
            ),
        ],
      ),
    );
  }
}
