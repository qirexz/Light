import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../data/workout_repository.dart';
import '../models/workout.dart';
import '../utils/format_utils.dart';
import 'workout_detail_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _repo = WorkoutRepository();
  late final TabController _tabController;

  List<Workout> _workouts = []; // unlimited - no time-window filtering
  Map<String, WorkoutStats> _stats = {};
  bool _loading = true;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final workouts = await _repo.getAllWorkouts(); // limit intentionally omitted
    final stats = await _repo.getStatsForAllWorkouts();
    if (!mounted) return;
    setState(() {
      _workouts = workouts;
      _stats = stats;
      _loading = false;
    });
  }

  List<Workout> _workoutsOnDay(DateTime day) {
    return _workouts.where((w) => isSameDay(w.startTime, day)).toList();
  }

  Future<void> _openWorkout(Workout workout) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workoutId: workout.id)),
    );
    if (result == true) _load(); // edited or deleted
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'List', icon: Icon(Icons.list)),
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListView(),
                _buildCalendarView(),
              ],
            ),
    );
  }

  Widget _buildListView() {
    if (_workouts.isEmpty) {
      return const _EmptyHistory();
    }

    // Group by "Month Year" for scannable section headers.
    final groups = <String, List<Workout>>{};
    for (final w in _workouts) {
      final key = formatMonthYear(w.startTime);
      groups.putIfAbsent(key, () => []).add(w);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              entry.key,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
          for (final workout in entry.value) _WorkoutTile(
            workout: workout,
            stats: _stats[workout.id] ?? WorkoutStats.empty,
            onTap: () => _openWorkout(workout),
          ),
        ],
      ],
    );
  }

  Widget _buildCalendarView() {
    final selected = _selectedDay;
    final dayWorkouts = selected == null ? <Workout>[] : _workoutsOnDay(selected);

    return Column(
      children: [
        TableCalendar<Workout>(
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => selected != null && isSameDay(selected, day),
          eventLoader: _workoutsOnDay,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(formatButtonVisible: false),
        ),
        const Divider(height: 1),
        Expanded(
          child: selected == null
              ? const Center(child: Text('Tap a day to see its workouts.'))
              : dayWorkouts.isEmpty
                  ? const Center(child: Text('No workouts on this day.'))
                  : ListView(
                      children: [
                        for (final w in dayWorkouts)
                          _WorkoutTile(
                            workout: w,
                            stats: _stats[w.id] ?? WorkoutStats.empty,
                            onTap: () => _openWorkout(w),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final Workout workout;
  final WorkoutStats stats;
  final VoidCallback onTap;

  const _WorkoutTile({required this.workout, required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final duration = workout.duration;
    return ListTile(
      leading: CircleAvatar(child: Text('${workout.startTime.day}')),
      title: Text(workout.name),
      subtitle: Text(
        '${formatWorkoutDate(workout.startTime)}'
        '${duration != null ? ' · ${formatDuration(duration)}' : ''}'
        ' · ${stats.exerciseCount} exercises · ${stats.completedSets} sets',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text('No workouts logged yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Finish a workout and it will show up here - your full history, with no time limit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
