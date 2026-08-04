import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../utils/exercise_analytics.dart';
import '../utils/format_utils.dart';

/// Plots session points on an evenly-spaced index axis (rather than a
/// true time axis) so that sessions far apart in time don't visually
/// compress a graph spanning years into a single cluster of points.
/// Date labels on the bottom axis are sparse so they stay readable
/// regardless of how many sessions exist.
class ProgressLineChart extends StatelessWidget {
  final List<SessionPoint> points;
  final Color color;

  const ProgressLineChart({super.key, required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            points.isEmpty
                ? 'Not enough data yet.'
                : 'Log one more session to see a trend line.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value),
    ];
    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15 + 1;

    // Show at most ~4 date labels, evenly spaced by index, regardless
    // of whether there are 5 sessions or 500.
    final labelCount = points.length > 4 ? 4 : points.length;
    final labelIndices = <int>{
      for (var i = 0; i < labelCount; i++)
        (i * (points.length - 1) / (labelCount - 1 == 0 ? 1 : labelCount - 1)).round(),
    };

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: (minY - padding).clamp(0, double.infinity),
          maxY: maxY + padding,
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
                      formatShortDate(points[index].date),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                final point = points[s.x.round()];
                return LineTooltipItem(
                  '${formatNumber(point.value)}\n${formatShortDate(point.date)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: points.length <= 30),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.15)),
            ),
          ],
        ),
      ),
    );
  }
}
