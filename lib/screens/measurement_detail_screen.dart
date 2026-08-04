import 'dart:io';
import 'package:flutter/material.dart';
import '../data/measurement_repository.dart';
import '../data/photo_storage.dart';
import '../models/measurement.dart';
import '../utils/enum_labels.dart';
import '../utils/exercise_analytics.dart';
import '../utils/format_utils.dart';
import '../widgets/progress_line_chart.dart';
import 'add_measurement_screen.dart';

class MeasurementDetailScreen extends StatefulWidget {
  final MeasurementType type;
  const MeasurementDetailScreen({super.key, required this.type});

  @override
  State<MeasurementDetailScreen> createState() => _MeasurementDetailScreenState();
}

class _MeasurementDetailScreenState extends State<MeasurementDetailScreen> {
  final _repo = MeasurementRepository();
  List<Measurement> _entries = []; // unlimited - full history, oldest first
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _repo.getEntriesForType(widget.type);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _addEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddMeasurementScreen(fixedType: widget.type),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _editEntry(Measurement entry) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddMeasurementScreen(fixedType: widget.type, existing: entry),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteEntry(Measurement entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('${formatWorkoutDate(entry.date)} · ${formatNumber(entry.value)} ${entry.unit}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PhotoStorage.deleteIfExists(entry.photoPath);
      await _repo.deleteMeasurement(entry.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final e in _entries) SessionPoint(date: e.date, value: e.value),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.type.label)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProgressLineChart(
                  points: points,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  'Every entry ever logged, no time limit.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 20),
                Text('History (${_entries.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_entries.isEmpty)
                  const Text(
                    'No entries yet. Tap "Add Entry" to log your first reading.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  for (final entry in _entries.reversed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: entry.photoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(entry.photoPath!),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const CircleAvatar(child: Icon(Icons.straighten)),
                      title: Text('${formatNumber(entry.value)} ${entry.unit}'),
                      subtitle: Text(formatWorkoutDate(entry.date)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') _editEntry(entry);
                          if (action == 'delete') _deleteEntry(entry);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }
}
