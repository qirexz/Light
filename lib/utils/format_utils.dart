import 'package:intl/intl.dart';

String formatWorkoutDate(DateTime date) => DateFormat('EEE, MMM d, yyyy').format(date);
String formatShortDate(DateTime date) => DateFormat('MMM d').format(date);
String formatTime(DateTime date) => DateFormat('h:mm a').format(date);
String formatMonthYear(DateTime date) => DateFormat('MMMM yyyy').format(date);

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Trims trailing ".0" so whole numbers don't show unnecessary decimals.
String formatNumber(num value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
