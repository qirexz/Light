import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/exercise_repository.dart';
import '../data/notification_service.dart';
import '../data/workout_repository.dart';
import '../state/active_workout_manager.dart';
import 'active_workout_screen.dart';
import 'analytics_screen.dart';
import 'exercise_library_screen.dart';
import 'measurements_screen.dart';
import 'personal_records_screen.dart';
import 'plate_calculator_screen.dart';
import 'routines_list_screen.dart';
import 'settings_screen.dart';
import 'workout_history_screen.dart';

/// Home dashboard: quick stats, start/resume workout, and a grid of
/// entry points into every other part of the app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _exerciseRepo = ExerciseRepository();
  final _workoutRepo = WorkoutRepository();

  int _exerciseCount = 0;
  int _workoutCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _exerciseRepo.seedIfEmpty();
      await _refreshCounts();
      // Ask for notification permission up front so the rest-timer
      // alert works the first time it's needed, rather than silently
      // failing. Harmless if the user declines - the in-app timer bar
      // is the source of truth regardless.
      unawaited(NotificationService.instance.requestPermissions());
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshCounts() async {
    final exercises = await _exerciseRepo.getAllExercises();
    final workouts = await _workoutRepo.getAllWorkouts();
    if (!mounted) return;
    setState(() {
      _exerciseCount = exercises.length;
      _workoutCount = workouts.length;
    });
  }

  Future<void> _startOrResumeWorkout() async {
    final manager = context.read<ActiveWorkoutManager>();
    if (!manager.isActive) {
      manager.startWorkout(name: 'Workout');
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
    await _refreshCounts();
  }

  Future<void> _navigate(Widget screen, {bool refreshOnReturn = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (refreshOnReturn) await _refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = context.watch<ActiveWorkoutManager>().isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _navigate(const SettingsScreen()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Database error: $_error'))
              : RefreshIndicator(
                  onRefresh: _refreshCounts,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Exercises', value: '$_exerciseCount')),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(label: 'Workouts', value: '$_workoutCount')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: Icon(isActive ? Icons.play_arrow : Icons.add),
                        label: Text(isActive ? 'Resume Workout' : 'Start Empty Workout'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _startOrResumeWorkout,
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _NavTile(
                            icon: Icons.list_alt,
                            label: 'Routines',
                            onTap: () => _navigate(const RoutinesListScreen()),
                          ),
                          _NavTile(
                            icon: Icons.history,
                            label: 'History',
                            onTap: () => _navigate(const WorkoutHistoryScreen(), refreshOnReturn: true),
                          ),
                          _NavTile(
                            icon: Icons.emoji_events_outlined,
                            label: 'Personal Records',
                            onTap: () => _navigate(const PersonalRecordsScreen()),
                          ),
                          _NavTile(
                            icon: Icons.insights,
                            label: 'Analytics',
                            onTap: () => _navigate(const AnalyticsScreen()),
                          ),
                          _NavTile(
                            icon: Icons.monitor_weight_outlined,
                            label: 'Measurements',
                            onTap: () => _navigate(const MeasurementsScreen()),
                          ),
                          _NavTile(
                            icon: Icons.fitness_center,
                            label: 'Exercise Library',
                            onTap: () => _navigate(const ExerciseLibraryScreen()),
                          ),
                          _NavTile(
                            icon: Icons.calculate_outlined,
                            label: 'Plate Calculator',
                            onTap: () => _navigate(const PlateCalculatorScreen()),
                          ),
                          _NavTile(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            onTap: () => _navigate(const SettingsScreen()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
