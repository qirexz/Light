import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/analytics_repository.dart';
import '../data/exercise_repository.dart';
import '../utils/enum_labels.dart';
import '../utils/format_utils.dart';
import 'exercise_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _repo = AnalyticsRepository();
  final _exerciseRepo = ExerciseRepository();

  OverallStats? _stats;
  List<WeeklyVolumePoint> _weeklyVolume = [];
  List<MuscleGroupCount> _muscleCounts = [];
  List<TopExercise> _topExercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await _repo.getOverallStats();
    final weekly = await _repo.getWeeklyVolume(); // unlimited - every week ever logged
    final muscles = await _repo.getMuscleGroupSetCounts();
    final top = await _repo.getTopExercises(limit: 8);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _weeklyVolume = weekly;
      _muscleCounts = muscles;
      _topExercises = top;
      _loading = false;
    });
  }

  Future<void> _openExercise(String exerciseId) async {
    final exercise = await _exerciseRepo.getExerciseById(exerciseId);
    if (exercise == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: exercise)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : stats == null || stats.workoutCount == 0
              ? const _EmptyAnalytics()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatsGrid(stats: stats),
                      const SizedBox(height: 28),
                      const Text('Weekly Volume',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Every week you\'ve trained, no time limit.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 12),
                      _WeeklyVolumeChart(points: _weeklyVolume),
                      const SizedBox(height: 28),
                      const Text('Muscle Group Balance',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Completed sets per primary muscle, all-time.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 12),
                      _MuscleBalanceChart(counts: _muscleCounts),
                      const SizedBox(height: 28),
                      const Text('Most Trained Exercises',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final ex in _topExercises)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.fitness_center),
                          title: Text(ex.name),
                          trailing: Text('${ex.setCount} sets',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () => _openExercise(ex.exerciseId),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final OverallStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Workouts', '${stats.workoutCount}'),
      ('Total Sets', '${stats.totalSets}'),
      ('Total Volume', formatNumber(stats.totalVolume)),
      ('Avg / Week', formatNumber(stats.avgWorkoutsPerWeek)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        for (final (label, value) in tiles)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeeklyVolumeChart extends StatelessWidget {
  final List<WeeklyVolumePoint> points;
  const _WeeklyVolumeChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text('No completed sets yet.', style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    final maxVolume = points.map((p) => p.volume).reduce((a, b) => a > b ? a : b);
    final labelCount = points.length > 4 ? 4 : points.length;
    final labelIndices = <int>{
      for (var i = 0; i < labelCount; i++)
        (i * (points.length - 1) / (labelCount - 1 == 0 ? 1 : labelCount - 1)).round(),
    };

    // Wide enough to scroll horizontally so it stays readable even
    // with years of weekly bars - unlimited history, not compressed.
    final chartWidth = (points.length * 28.0).clamp(
      MediaQuery.of(context).size.width - 32,
      double.infinity,
    );

    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: SizedBox(
          width: chartWidth,
          child: BarChart(
            BarChartData(
              maxY: maxVolume * 1.15 + 1,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) => Text(
                      formatNumber(value),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (!labelIndices.contains(index) || index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          formatShortDate(points[index].weekStart),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: points[i].volume,
                      color: Theme.of(context).colorScheme.primary,
                      width: 14,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuscleBalanceChart extends StatelessWidget {
  final List<MuscleGroupCount> counts;
  const _MuscleBalanceChart({required this.counts});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) {
      return Text('No completed sets yet.', style: TextStyle(color: Colors.grey.shade500));
    }
    final maxCount = counts.map((c) => c.setCount).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final c in counts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text(c.muscle.label, style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxCount == 0 ? 0 : c.setCount / maxCount,
                      minHeight: 14,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text('${c.setCount}',
                      textAlign: TextAlign.end, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text('No data yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Log a few workouts and your volume trends, muscle balance, and top exercises will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
