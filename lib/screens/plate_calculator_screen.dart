import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/settings_manager.dart';
import '../utils/format_utils.dart';
import '../utils/units.dart';

class _PlateBreakdown {
  final List<MapEntry<double, int>> plates; // plate weight -> count per side
  final double loadedPerSide;
  final double remainder; // weight that couldn't be matched exactly
  const _PlateBreakdown({required this.plates, required this.loadedPerSide, required this.remainder});
}

class PlateCalculatorScreen extends StatefulWidget {
  const PlateCalculatorScreen({super.key});

  @override
  State<PlateCalculatorScreen> createState() => _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState extends State<PlateCalculatorScreen> {
  late UnitSystem _unit;
  late final TextEditingController _targetController;
  late final TextEditingController _barController;

  @override
  void initState() {
    super.initState();
    _unit = context.read<SettingsManager>().unitSystem;
    _barController = TextEditingController(text: formatNumber(_unit.defaultBarWeight));
    _targetController = TextEditingController();
  }

  @override
  void dispose() {
    _targetController.dispose();
    _barController.dispose();
    super.dispose();
  }

  List<double> get _availablePlates => _unit == UnitSystem.metric
      ? const [25, 20, 15, 10, 5, 2.5, 1.25]
      : const [45, 35, 25, 10, 5, 2.5];

  _PlateBreakdown _calculate(double target, double barWeight) {
    var perSide = (target - barWeight) / 2;
    if (perSide < 0) perSide = 0;
    final plates = <MapEntry<double, int>>[];
    var remaining = perSide;
    for (final plate in _availablePlates) {
      final count = (remaining / plate).floor();
      if (count > 0) {
        plates.add(MapEntry(plate, count));
        remaining -= plate * count;
      }
    }
    // Guard against floating point noise leaving a near-zero remainder.
    if (remaining < 0.01) remaining = 0;
    return _PlateBreakdown(
      plates: plates,
      loadedPerSide: perSide - remaining,
      remainder: remaining,
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = double.tryParse(_targetController.text) ?? 0;
    final bar = double.tryParse(_barController.text) ?? _unit.defaultBarWeight;
    final breakdown = _calculate(target, bar);
    final unitLabel = _unit.weightUnit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plate Calculator'),
        actions: [
          PopupMenuButton<UnitSystem>(
            initialValue: _unit,
            onSelected: (u) => setState(() {
              _unit = u;
              _barController.text = formatNumber(u.defaultBarWeight);
            }),
            itemBuilder: (context) => [
              for (final u in UnitSystem.values)
                PopupMenuItem(value: u, child: Text(u.weightUnit)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Target weight ($unitLabel)',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _barController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: 'Bar weight ($unitLabel)',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (target <= 0)
            Text('Enter a target weight to see the plate breakdown.',
                style: TextStyle(color: Colors.grey.shade500))
          else ...[
            const Text('Per side', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            if (breakdown.plates.isEmpty)
              Text(
                target <= bar
                    ? 'Bar alone meets or exceeds this target.'
                    : 'No plates needed for this amount.',
                style: const TextStyle(fontSize: 16),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in breakdown.plates)
                    _PlateChip(weight: entry.key, count: entry.value, unit: unitLabel),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              'Loaded per side: ${formatNumber(breakdown.loadedPerSide)} $unitLabel'
              '${breakdown.remainder > 0 ? ' (${formatNumber(breakdown.remainder)} $unitLabel short of exact - no combination of available plates hits it precisely)' : ''}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${formatNumber(bar + breakdown.loadedPerSide * 2)} $unitLabel (bar + both sides)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  final double weight;
  final int count;
  final String unit;
  const _PlateChip({required this.weight, required this.count, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${formatNumber(weight)} $unit  ×$count',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
