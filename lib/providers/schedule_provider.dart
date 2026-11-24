import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/schedule.dart';

class ScheduleProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://pen-patrol-db-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();
  StreamSubscription<DatabaseEvent>? _scheduleSub;

  List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Schedule> get schedules => List.unmodifiable(_schedules);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ScheduleProvider() {
    _listenToSchedules();
  }

  /// Real-time stream of Swine Bath schedules from Firebase
  void _listenToSchedules() {
    _isLoading = true;
    notifyListeners();

    _scheduleSub?.cancel();
    _scheduleSub = _dbRef.child('swine_bath_schedules').onValue.listen((event) {
      _isLoading = false;
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final rawMap = Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<Schedule> loaded = [];

        rawMap.forEach((key, value) {
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            loaded.add(Schedule(
              id: key,
              title: data['title']?.toString() ?? 'Swine Bath',
              time: data['time']?.toString() ?? '08:00',
              selectedDays: List<String>.from(data['selectedDays'] ?? []),
              enabled: data['enabled'] as bool? ?? false,
              intensity: (data['intensity'] as num?)?.toDouble() ??
                  Schedule.defaultIntensity,
              duration: (data['duration'] as num?)?.toDouble() ??
                  Schedule.defaultDurationMinutes,
            ));
          }
        });

        _schedules = loaded;
      } else {
        _schedules = [];
      }
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();
    });
  }

  /// Fetch snapshot for Pull-to-Refresh
  Future<void> fetchSchedules() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _dbRef.child('swine_bath_schedules').get();
      _isLoading = false;

      if (snapshot.exists && snapshot.value is Map) {
        final rawMap = Map<String, dynamic>.from(snapshot.value as Map);
        final List<Schedule> loaded = [];

        rawMap.forEach((key, value) {
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            loaded.add(Schedule(
              id: key,
              title: data['title']?.toString() ?? 'Swine Bath',
              time: data['time']?.toString() ?? '08:00',
              selectedDays: List<String>.from(data['selectedDays'] ?? []),
              enabled: data['enabled'] as bool? ?? false,
              intensity: (data['intensity'] as num?)?.toDouble() ??
                  Schedule.defaultIntensity,
              duration: (data['duration'] as num?)?.toDouble() ??
                  Schedule.defaultDurationMinutes,
            ));
          }
        });

        _schedules = loaded;
      } else {
        _schedules = [];
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load schedules.';
    } finally {
      notifyListeners();
    }
  }

  /// Add a new swine bath schedule to Firebase
  Future<void> addSchedule(Schedule schedule) async {
    final Map<String, dynamic> scheduleData = {
      'title': schedule.title,
      'time': schedule.time,
      'selectedDays': schedule.selectedDays,
      'enabled': schedule.enabled,
      'intensity': schedule.intensity,
      'duration': schedule.duration,
    };

    // Save schedule node
    await _dbRef.child('swine_bath_schedules/${schedule.id}').set(scheduleData);

    // If enabled on creation, turn OFF all other schedules & update Arduino controls
    if (schedule.enabled) {
      await toggleEnabled(schedule.id, true);
    }
  }

  /// Update an existing swine bath schedule in Firebase
  Future<void> updateSchedule(Schedule schedule) async {
    final Map<String, dynamic> scheduleData = {
      'title': schedule.title,
      'time': schedule.time,
      'selectedDays': schedule.selectedDays,
      'enabled': schedule.enabled,
      'intensity': schedule.intensity,
      'duration': schedule.duration,
    };

    await _dbRef.child('swine_bath_schedules/${schedule.id}').set(scheduleData);

    if (schedule.enabled) {
      await _syncHardwareControlNode(activeScheduleOverride: schedule);
    }
  }

  /// Delete schedule from Firebase
  Future<void> removeSchedule(String id) async {
    await _dbRef.child('swine_bath_schedules/$id').remove();
    await _syncHardwareControlNode();
  }

  /// Toggle schedule ON/OFF in Firebase
  Future<void> toggleEnabled(String id, bool value) async {
    final updates = <String, dynamic>{};

    if (value) {
      // Single active schedule rule: Turn this ON and ALL others OFF
      for (final s in _schedules) {
        updates['swine_bath_schedules/${s.id}/enabled'] = (s.id == id);
      }
    } else {
      updates['swine_bath_schedules/$id/enabled'] = false;
    }

    await _dbRef.update(updates);
    await _syncHardwareControlNode();
  }

  /// Syncs active schedule parameters directly to the Arduino node in Firebase
  /// Modifies `pump1_pen` (5V Relay) and `valve1_pen` (0-90° Servo on PCA9685)
  Future<void> _syncHardwareControlNode(
      {Schedule? activeScheduleOverride}) async {
    final activeSchedule = activeScheduleOverride ??
        _schedules.cast<Schedule?>().firstWhere(
              (s) => s != null && s.enabled,
              orElse: () => null,
            );

    if (activeSchedule != null) {
      // Map Intensity (0 - 100%) to PCA9685 Servo Angle (0° to 90°)
      final int servoAngle =
          ((activeSchedule.intensity / 100.0) * 90.0).round();

      await _dbRef.child('controls/swine_bath').set({
        'pump1_pen': true, // Turn ON 5V relay for pump
        'valve1_pen': servoAngle, // Open Servo via PCA9685
        'intensity_percent': activeSchedule.intensity,
        'duration_minutes': activeSchedule.duration,
        'active_schedule_id': activeSchedule.id,
        'title': activeSchedule.title,
        'time': activeSchedule.time,
        'selectedDays': activeSchedule.selectedDays,
      });
    } else {
      // Turn OFF hardware controls when no schedule is active
      await _dbRef.child('controls/swine_bath').set({
        'pump1_pen': false, // Turn OFF relay
        'valve1_pen': 0, // Close Servo (0 degrees)
        'intensity_percent': 0.0,
        'duration_minutes': 0.0,
        'active_schedule_id': null,
      });
    }
  }

  @override
  void dispose() {
    _scheduleSub?.cancel();
    super.dispose();
  }
}
