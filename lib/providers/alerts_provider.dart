import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert.dart';

class AlertsProvider extends ChangeNotifier {
  List<Alert> _alerts = [];
  bool _isLoading = false;
  String? _errorMessage;

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
        _alerts = fetchedAlerts;
      } else {
        _alerts = [];
      }
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
}