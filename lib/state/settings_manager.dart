import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/notification_service.dart';
import '../utils/units.dart';

const _kUnitSystemKey = 'unit_system';
const _kDefaultRestSecondsKey = 'default_rest_seconds';
const _kNotificationsEnabledKey = 'notifications_enabled';

/// App-wide preferences, persisted to disk via shared_preferences and
/// loaded once at startup. Lives above the navigator (via Provider)
/// alongside ActiveWorkoutManager so any screen can read or change it.
class SettingsManager extends ChangeNotifier {
  UnitSystem _unitSystem = UnitSystem.metric;
  int _defaultRestSeconds = 90;
  bool _notificationsEnabled = true;
  bool _loaded = false;

  UnitSystem get unitSystem => _unitSystem;
  int get defaultRestSeconds => _defaultRestSeconds;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(_kUnitSystemKey);
    _unitSystem = unitString == 'imperial' ? UnitSystem.imperial : UnitSystem.metric;
    _defaultRestSeconds = prefs.getInt(_kDefaultRestSecondsKey) ?? 90;
    _notificationsEnabled = prefs.getBool(_kNotificationsEnabledKey) ?? true;
    NotificationService.instance.enabled = _notificationsEnabled;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    _unitSystem = system;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnitSystemKey, system == UnitSystem.imperial ? 'imperial' : 'metric');
  }

  Future<void> setDefaultRestSeconds(int seconds) async {
    _defaultRestSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDefaultRestSecondsKey, seconds);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    NotificationService.instance.enabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabledKey, enabled);
  }
}
