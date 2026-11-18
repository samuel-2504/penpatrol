import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/history_log.dart';

class HistoryProvider extends ChangeNotifier {
  static const List<String> _legacyDemoLogIds = [
    'log_d1_1',
    'log_d1_2',
    'log_d1_3',
    'log_d1_4',
    'log_d1_5',
    'log_d2_1',
    'log_d2_2',
    'log_d2_3',
    'log_d2_4',
    'log_d2_5',
    'log_d3_1',
    'log_d3_2',
    'log_d3_3',
    'log_d3_4',
    'log_d3_5',
  ];

  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://pen-patrol-db-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();
  StreamSubscription<DatabaseEvent>? _logsSub;

  List<HistoryLog> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<HistoryLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  HistoryProvider() {
    listenToLogs();
    unawaited(_removeLegacyDemoLogs());
  }

  /// Real-time stream listener for Firebase Database history logs
  void listenToLogs() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _logsSub?.cancel();
    _logsSub = _dbRef.child('history_logs').onValue.listen(
      (event) {
        _isLoading = false;
        _logs = _parseLogs(event.snapshot.value);
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Failed to sync activity history.';
        debugPrint('Error syncing activity history: $error');
        notifyListeners();
      },
    );
  }

  List<HistoryLog> _parseLogs(Object? value) {
    if (value is! Map) return [];

    final loadedLogs = <HistoryLog>[];
    for (final entry in value.entries) {
      if (_legacyDemoLogIds.contains(entry.key.toString())) continue;
      if (entry.value is! Map) continue;

      final data = Map<String, dynamic>.from(entry.value as Map);
      final timestampValue = data['timestamp'];
      final DateTime? timestamp;
      if (timestampValue is num) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(
          timestampValue.toInt(),
        );
      } else if (timestampValue is String) {
        timestamp = DateTime.tryParse(timestampValue);
      } else {
        timestamp = null;
      }

      if (timestamp == null) {
        debugPrint(
            'Skipping history record with invalid timestamp: ${entry.key}');
        continue;
      }

      loadedLogs.add(
        HistoryLog(
          id: entry.key.toString(),
          category: data['category']?.toString() ?? 'System',
          title: data['title']?.toString() ?? 'Log Entry',
          description: data['description']?.toString() ?? '',
          timestamp: timestamp,
        ),
      );
    }

    loadedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return loadedLogs;
  }

  Future<void> _removeLegacyDemoLogs() async {
    try {
      await _dbRef.child('history_logs').update({
        for (final id in _legacyDemoLogIds) id: null,
      });
    } catch (e) {
      _errorMessage = 'Failed to remove legacy demo history from Firebase.';
      debugPrint('Error removing legacy demo history: $e');
      notifyListeners();
    }
  }

  /// On-demand snapshot fetch for Pull-To-Refresh support
  Future<void> fetchLogs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _dbRef.child('history_logs').get();
      _logs = _parseLogs(snapshot.value);
    } catch (e) {
      _errorMessage = 'Failed to load history logs.';
      debugPrint('Error fetching history logs: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Push a new log entry to Firebase Realtime Database
  Future<void> addLog({
    required String category,
    required String title,
    required String description,
  }) async {
    try {
      final newRef = _dbRef.child('history_logs').push();
      await newRef.set({
        'category': category,
        'title': title,
        'description': description,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Error adding history log: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _logsSub?.cancel();
    super.dispose();
  }
}
