import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert.dart';

class AlertsProvider extends ChangeNotifier {
  static const List<String> _legacyDemoAlertIds = [
    'alert_d1_1',
    'alert_d1_2',
    'alert_d1_3',
    'alert_d1_4',
    'alert_d1_5',
  ];

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
    unawaited(_removeLegacyDemoAlerts());
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
        _alerts = _parseAlerts(event.snapshot.value);
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _errorMessage = 'Failed to sync alerts with Firebase.';
        debugPrint('Error syncing alerts: $e');
        notifyListeners();
      },
    );
  }

  List<Alert> _parseAlerts(Object? value) {
    if (value is! Map) return [];

    final fetchedAlerts = <Alert>[];
    for (final entry in value.entries) {
      if (_legacyDemoAlertIds.contains(entry.key.toString())) continue;
      if (entry.value is! Map) continue;

      try {
        final alertData = Map<String, dynamic>.from(entry.value as Map);
        alertData['id'] = entry.key.toString();
        fetchedAlerts.add(Alert.fromJson(alertData));
      } on FormatException catch (e) {
        debugPrint('Skipping invalid Firebase alert ${entry.key}: $e');
      }
    }

    fetchedAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return fetchedAlerts;
  }

  Future<void> _removeLegacyDemoAlerts() async {
    try {
      await _db.update({
        for (final id in _legacyDemoAlertIds) id: null,
      });
    } catch (e) {
      _errorMessage = 'Failed to remove legacy demo alerts from Firebase.';
      debugPrint('Error removing legacy demo alerts: $e');
      notifyListeners();
    }
  }

  /// Fetch alerts from the database
  Future<void> fetchAlerts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _db.get();

      _alerts = _parseAlerts(snapshot.value);
    } catch (e) {
      _errorMessage = 'Failed to fetch alerts. Please try again.';
      debugPrint('Error fetching alerts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
