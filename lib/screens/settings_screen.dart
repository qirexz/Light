import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/backup_service.dart';
import '../data/database_helper.dart';
import '../data/notification_service.dart';
import '../state/settings_manager.dart';
import '../utils/units.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backupService = BackupService();
  bool _busy = false;

  Future<void> _exportData() async {
    setState(() => _busy = true);
    try {
      final json = await _backupService.exportAll();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/gym_tracker_backup_$stamp.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)], text: 'Gym Tracker backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
          'This will merge the backup into your current data. Entries '
          'with matching ids will be overwritten; everything else is '
          'added alongside what you already have. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final content = await File(result.files.single.path!).readAsString();
      await _backupService.importAll(content);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Import complete.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This permanently deletes every workout, routine, measurement, '
          'and record, then reseeds the built-in exercise library. '
          'Consider exporting a backup first. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    await DatabaseHelper.instance.clearAllData();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared. Restart the app to reseed the library.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.5 : 1,
          child: ListView(
            children: [
              const _SectionHeader('Units'),
              for (final system in UnitSystem.values)
                RadioListTile<UnitSystem>(
                  title: Text(system.label),
                  value: system,
                  groupValue: settings.unitSystem,
                  onChanged: (v) {
                    if (v != null) settings.setUnitSystem(v);
                  },
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Controls default labels (e.g. the plate calculator and '
                  'new measurement entries). It doesn\'t convert numbers '
                  'you\'ve already logged.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
              const Divider(),
              const _SectionHeader('Workout'),
              ListTile(
                title: const Text('Default rest timer'),
                subtitle: Text('${settings.defaultRestSeconds} seconds'),
                trailing: SizedBox(
                  width: 160,
                  child: Slider(
                    min: 15,
                    max: 300,
                    divisions: 19,
                    value: settings.defaultRestSeconds.toDouble(),
                    label: '${settings.defaultRestSeconds}s',
                    onChanged: (v) => settings.setDefaultRestSeconds(v.round()),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Rest timer notifications'),
                subtitle: const Text('Alert when rest is done, even if the app is backgrounded'),
                value: settings.notificationsEnabled,
                onChanged: (v) async {
                  settings.setNotificationsEnabled(v);
                  if (v) await NotificationService.instance.requestPermissions();
                },
              ),
              const Divider(),
              const _SectionHeader('Backup'),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Export data'),
                subtitle: const Text('Save a backup file of all your workouts, routines, and measurements'),
                onTap: _exportData,
              ),
              const Divider(),
              const _SectionHeader('Danger Zone'),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                title: const Text('Reset all data', style: TextStyle(color: Colors.red)),
                onTap: _resetAllData,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
