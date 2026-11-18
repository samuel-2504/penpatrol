import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert.dart';

class AlertsProvider extends ChangeNotifier {
  List<Alert> _alerts = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<DatabaseEvent>? _alertsSub;

  // Firebase Realtime Database reference for alerts
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://pen-patrol-db-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref('alerts');

  List<Alert> get alerts => List.unmodifiable(_alerts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _alerts.where((a) => !a.read).length;

  AlertsProvider() {
    _listenToAlerts();
  }

  /// Real-time stream listener for Firebase Database alerts
  void _listenToAlerts() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _alertsSub?.cancel();
    _alertsSub = _db.onValue.listen(
      (event) {
        _isLoading = false;
        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final dataMap = event.snapshot.value as Map<dynamic, dynamic>;
          final List<Alert> fetchedAlerts = dataMap.entries.map((entry) {
            final Map<String, dynamic> alertData =
                Map<String, dynamic>.from(entry.value as Map);
            alertData['id'] = entry.key;
            return Alert.fromJson(alertData);
          }).toList();

          fetchedAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          if (fetchedAlerts.isEmpty) {
            _seedInitialAlerts();
            return;
          }
          _alerts = fetchedAlerts;
        } else {
          _seedInitialAlerts();
          return;
        }
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        if (_alerts.isEmpty) {
          _seedInitialAlerts();
        } else {
          _errorMessage = 'Failed to sync alerts with Firebase.';
          notifyListeners();
        }
      },
    );
  }

  /// Fetch alerts from the database
  Future<void> fetchAlerts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _db.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final dataMap = snapshot.value as Map<dynamic, dynamic>;
        
        final List<Alert> fetchedAlerts = dataMap.entries.map((entry) {
          final Map<String, dynamic> alertData = 
              Map<String, dynamic>.from(entry.value as Map);
          
          // Ensure the Firebase node key is used as the document ID
          alertData['id'] = entry.key;
          return Alert.fromJson(alertData);
        }).toList();

        // Sort descending by timestamp (newest first)
        fetchedAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (fetchedAlerts.isEmpty) {
          _seedInitialAlerts();
          return;
        }
        _alerts = fetchedAlerts;
      } else {
        _seedInitialAlerts();
        return;
      }
    } catch (e) {
      if (_alerts.isEmpty) {
        _seedInitialAlerts();
        return;
      }
      _errorMessage = 'Failed to fetch alerts. Please try again.';
      debugPrint('Error fetching alerts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _seedInitialAlerts() {
    final now = DateTime.now();
    final seeds = [
      Alert(
        id: 'alert_d1_1',
        title: 'Elevated Heat Detected in Pen 2',
        subtitle: 'MLX90640 recorded 38.8°C at north-east corner',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 15)),
        severity: AlertSeverity.critical,
        read: false,
      ),
      Alert(
        id: 'alert_d1_2',
        title: 'Foot Bath Cycle Complete',
        subtitle: '10-second disinfection cycle finished via Servo 7 and Pump 2',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 30)),
        severity: AlertSeverity.info,
        read: false,
      ),
      Alert(
        id: 'alert_d1_3',
        title: 'Corridor Movement Detected',
        subtitle: 'ToF Sensor VL53L1X sensed motion at 1.2m range',
        timestamp: now.subtract(const Duration(hours: 6, minutes: 45)),
        severity: AlertSeverity.warning,
        read: true,
      ),
      Alert(
        id: 'alert_d1_4',
        title: 'Disinfection Tunnel Primed',
        subtitle: 'Pump 2 (Relay 2) and Servo 6 ready for transport sanitization',
        timestamp: now.subtract(const Duration(hours: 8, minutes: 20)),
        severity: AlertSeverity.info,
        read: true,
      ),
      Alert(
        id: 'alert_d1_5',
        title: 'Morning Swine Bath Finished',
        subtitle: 'Servos 1-4 rotated and Pump 1 (Relay 1) cooling cycle executed',
        timestamp: now.subtract(const Duration(hours: 11, minutes: 10)),
        severity: AlertSeverity.info,
        read: true,
      ),
    ];

    _alerts = seeds;
    _isLoading = false;
    notifyListeners();

    for (final a in seeds) {
      _db.child(a.id).set(a.toJson()).catchError((_) {});
    }
  }

  /// Delete a single alert from the database
  Future<void> dismiss(String id) async {
    final originalList = List<Alert>.from(_alerts);
    _alerts.removeWhere((a) => a.id == id);
    notifyListeners();

    try {
      // Remove specific alert node from Firebase
      await _db.child(id).remove();
    } catch (e) {
      // Rollback on failure
      _alerts = originalList;
      notifyListeners();
      debugPrint('Error dismissing alert: $e');
      rethrow;
    }
  }

  /// Clear all active alerts
  Future<void> clearAll() async {
    final originalList = List<Alert>.from(_alerts);
    _alerts.clear();
    notifyListeners();

    try {
      // Remove all children under the 'alerts' node
      await _db.remove();
    } catch (e) {
      // Rollback on failure
      _alerts = originalList;
      notifyListeners();
      debugPrint('Error clearing alerts: $e');
      rethrow;
    }
  }

  /// Mark all alerts as read
  Future<void> markAllRead() async {
    final Map<String, dynamic> updates = {};
    
    // Update local state and prepare Firebase batch updates
    for (final a in _alerts) {
      if (!a.read) {
        a.read = true;
        // The path targets the specific alert ID and updates its 'read' property
        updates['${a.id}/read'] = true;
      }
    }
    
    if (updates.isNotEmpty) {
      notifyListeners();
      try {
        // Apply batched update to Firebase
        await _db.update(updates);
      } catch (e) {
        debugPrint('Error marking alerts as read: $e');
        // Handle error if needed (e.g., rollback)
      }
    }
  }

  /// Add a new alert to database & state
  Future<void> addAlert(Alert alert) async {
    try {
      // Generate a new unique key for the push
      final newRef = _db.push();
      final newId = newRef.key;

      if (newId != null) {
        final alertData = alert.toJson();
        alertData['id'] = newId;

        // Save to Firebase
        await newRef.set(alertData);
        
        // Add to local state (at the top of the list)
        _alerts.insert(0, Alert.fromJson(alertData));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding alert: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    super.dispose();
  }
}