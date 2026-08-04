import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/active_workout_manager.dart';

class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key});

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ActiveWorkoutManager>();
    if (!manager.isResting) return const SizedBox.shrink();

    final progress = manager.restTotalSeconds == 0
        ? 0.0
        : manager.restSecondsRemaining / manager.restTotalSeconds;

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: progress, strokeWidth: 3),
                    const Icon(Icons.timer, size: 18),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('Rest: ${_format(manager.restSecondsRemaining)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                tooltip: '-15s',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => manager.addRestSeconds(-15),
              ),
              IconButton(
                tooltip: '+15s',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => manager.addRestSeconds(15),
              ),
              TextButton(
                onPressed: manager.skipRest,
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
