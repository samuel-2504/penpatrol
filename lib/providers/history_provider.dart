import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/history_log.dart';

class HistoryProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _logsSub;

  List<HistoryLog> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<HistoryLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  HistoryProvider() {
    listenToLogs();
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
        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final Map<dynamic, dynamic> rawMap =
              event.snapshot.value as Map<dynamic, dynamic>;

          final List<HistoryLog> loadedLogs = [];

          rawMap.forEach((key, value) {
            if (value is Map) {
              final Map<String, dynamic> data =
                  Map<String, dynamic>.from(value);

              // Parse timestamp safely (supports Epoch milliseconds or ISO-8601 String)
              DateTime parsedDate;
              if (data['timestamp'] is int) {
                parsedDate = DateTime.fromMillisecondsSinceEpoch(
                    data['timestamp'] as int);
              } else if (data['timestamp'] is String) {
                parsedDate =
                    DateTime.tryParse(data['timestamp'] as String) ??
                        DateTime.now();
              } else {
                parsedDate = DateTime.now();
              }

              loadedLogs.add(
                HistoryLog(
                  id: key.toString(),
                  category: data['category']?.toString() ?? 'System',
                  title: data['title']?.toString() ?? 'Log Entry',
                  description: data['description']?.toString() ?? '',
                  timestamp: parsedDate,
                ),
              );
            }
          });

          // Sort logs newest first
          loadedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _logs = loadedLogs;
        } else {
          _logs = [];
        }
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Failed to sync activity history: ${error.toString()}';
        notifyListeners();
      },
    );
  }

  /// On-demand snapshot fetch for Pull-To-Refresh support
  Future<void> fetchLogs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _dbRef.child('history_logs').get();
      _isLoading = false;

      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> rawMap =
            snapshot.value as Map<dynamic, dynamic>;
        final List<HistoryLog> loadedLogs = [];

        rawMap.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(value);

            DateTime parsedDate;
            if (data['timestamp'] is int) {
              parsedDate = DateTime.fromMillisecondsSinceEpoch(
                  data['timestamp'] as int);
            } else if (data['timestamp'] is String) {
              parsedDate =
                  DateTime.tryParse(data['timestamp'] as String) ??
                      DateTime.now();
            } else {
              parsedDate = DateTime.now();
            }

            loadedLogs.add(
              HistoryLog(
                id: key.toString(),
                category: data['category']?.toString() ?? 'System',
                title: data['title']?.toString() ?? 'Log Entry',
                description: data['description']?.toString() ?? '',
                timestamp: parsedDate,
              ),
            );
          }
        });

        loadedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _logs = loadedLogs;
      } else {
        _logs = [];
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load history logs.';
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
      rethrow;
    }
  }

  @override
  void dispose() {
    _logsSub?.cancel();
    super.dispose();
  }
}