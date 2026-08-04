import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../models/workout_set.dart';

/// A single editable set row. Manages its own text controllers so
/// typing doesn't get interrupted by parent rebuilds - values are
/// pushed up to the ActiveWorkoutManager via the callbacks, not pulled
/// back down into the controllers.
class SetRow extends StatefulWidget {
  final WorkoutSet set;
  final ExerciseType exerciseType;
  final void Function({double? weight, int? reps}) onChanged;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const SetRow({
    super.key,
    required this.set,
    required this.exerciseType,
    required this.onChanged,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
        text: widget.set.weight == null ? '' : _trimZero(widget.set.weight!));
    _repsController =
        TextEditingController(text: widget.set.reps?.toString() ?? '');
  }

  String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  bool get _showWeight =>
      widget.exerciseType == ExerciseType.weightReps ||
      widget.exerciseType == ExerciseType.weightedBodyweight;
  bool get _showReps =>
      widget.exerciseType == ExerciseType.weightReps ||
      widget.exerciseType == ExerciseType.bodyweightReps ||
      widget.exerciseType == ExerciseType.weightedBodyweight;

  @override
  Widget build(BuildContext context) {
    final completed = widget.set.isCompleted;
    return Container(
      color: completed
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${widget.set.setNumber}',
                textAlign: TextAlign.center),
          ),
          if (_showWeight)
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '0',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) widget.onChanged(weight: parsed);
                },
              ),
            ),
          if (_showWeight) const SizedBox(width: 6),
          if (_showReps)
            Expanded(
              child: TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '0',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) widget.onChanged(reps: parsed);
                },
              ),
            ),
          SizedBox(
            width: 44,
            child: IconButton(
              icon: Icon(
                completed ? Icons.check_circle : Icons.check_circle_outline,
                color: completed ? Colors.green : null,
              ),
              onPressed: widget.onToggleComplete,
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
