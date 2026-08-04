import 'package:flutter/material.dart';
import '../data/measurement_repository.dart';
import '../models/measurement.dart';
import '../utils/enum_labels.dart';
import '../utils/format_utils.dart';
import 'add_measurement_screen.dart';
import 'measurement_detail_screen.dart';
import 'progress_photos_screen.dart';

class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  final _repo = MeasurementRepository();
  Map<MeasurementType, Measurement> _latest = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final latest = await _repo.getLatestByType();
    if (!mounted) return;
    setState(() {
      _latest = latest;
      _loading = false;
    });
  }

  Future<void> _addEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddMeasurementScreen()),
    );
    if (saved == true) _load();
  }

  Future<void> _openType(MeasurementType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MeasurementDetailScreen(type: type)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Progress photos',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProgressPhotosScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: MeasurementType.values.length,
              itemBuilder: (context, index) {
                final type = MeasurementType.values[index];
                final latest = _latest[type];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(type == MeasurementType.bodyWeight
                        ? Icons.monitor_weight_outlined
                        : Icons.straighten),
                  ),
                  title: Text(type.label),
                  subtitle: Text(
                    latest == null
                        ? 'No entries yet'
                        : 'Last: ${formatShortDate(latest.date)}',
                  ),
                  trailing: latest == null
                      ? const Icon(Icons.chevron_right)
                      : Text(
                          '${formatNumber(latest.value)} ${latest.unit}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                  onTap: () => _openType(type),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }
}
