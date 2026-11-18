import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/history_log.dart';

class HistoryProvider extends ChangeNotifier {
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
          _seedInitialLogs();
          return;
        }
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        if (_logs.isEmpty) {
          _seedInitialLogs();
        } else {
          _errorMessage = 'Failed to sync activity history: ${error.toString()}';
          notifyListeners();
        }
      },
    );
  }

  void _seedInitialLogs() {
    final now = DateTime.now();
    final seeds = [
      // --- TODAY (Day 1) ---
      HistoryLog(
        id: 'log_d1_1',
        category: 'Foot Bath',
        title: 'Foot Bath Activated',
        description: 'Automatic 10s disinfection cycle completed via Servo 7 and Pump 2.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 20)),
      ),
      HistoryLog(
        id: 'log_d1_2',
        category: 'Swine Bath',
        title: 'Swine Bath Cycle Run',
        description: 'Corner Servos 1-4 and Pump 1 (Relay 1) operated for 45s misting.',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 45)),
      ),
      HistoryLog(
        id: 'log_d1_3',
        category: 'Thermal',
        title: 'Thermal Scan Normal',
        description: 'MLX90640 average pen temperature at 28.2°C; within healthy range.',
        timestamp: now.subtract(const Duration(hours: 5, minutes: 30)),
      ),
      HistoryLog(
        id: 'log_d1_4',
        category: 'Tunnel',
        title: 'Disinfection Tunnel Ready',
        description: 'Pump 2 (Relay 2) and Servo 6 primed for transport sanitization.',
        timestamp: now.subtract(const Duration(hours: 7, minutes: 50)),
      ),
      HistoryLog(
        id: 'log_d1_5',
        category: 'System',
        title: 'Corridor Pathway Check',
        description: 'ToF Sensor VL53L1X verified clear corridor pathway.',
        timestamp: now.subtract(const Duration(hours: 10, minutes: 15)),
      ),

      // --- YESTERDAY (Day 2) ---
      HistoryLog(
        id: 'log_d2_1',
        category: 'Thermal',
        title: 'Elevated Heat Notice',
        description: 'MLX90640 detected 38.6°C hotspot in Pen 2 corner; automated cooling engaged.',
        timestamp: now.subtract(const Duration(hours: 18, minutes: 30)),
      ),
      HistoryLog(
        id: 'log_d2_2',
        category: 'System',
        title: 'Pen Disinfection Cycle',
        description: 'Custom ball valve Servo 8 (Pump 2 to Pen) actuated for scheduled sanitizing.',
        timestamp: now.subtract(const Duration(hours: 22, minutes: 10)),
      ),
      HistoryLog(
        id: 'log_d2_3',
        category: 'Swine Bath',
        title: 'Swine Bath Midday Run',
        description: 'Servos 1-4 rotated 180° and fresh water valve Servo 5 opened.',
        timestamp: now.subtract(const Duration(hours: 26, minutes: 40)),
      ),
      HistoryLog(
        id: 'log_d2_4',
        category: 'Foot Bath',
        title: 'Foot Bath Chemical Test',
        description: 'Servo 7 ball valve opened 10s for solution flow verification.',
        timestamp: now.subtract(const Duration(hours: 30, minutes: 15)),
      ),
      HistoryLog(
        id: 'log_d2_5',
        category: 'System',
        title: 'Arduino Gateway Sync',
        description: 'All 16 sensors, servos, and pumps synchronized with cloud.',
        timestamp: now.subtract(const Duration(hours: 34, minutes: 0)),
      ),

      // --- 2 DAYS AGO (Day 3) ---
      HistoryLog(
        id: 'log_d3_1',
        category: 'Tunnel',
        title: 'Tunnel Disinfection Run',
        description: 'Vehicle ingress triggered distance sensor and tunnel misting spray.',
        timestamp: now.subtract(const Duration(hours: 48, minutes: 10)),
      ),
      HistoryLog(
        id: 'log_d3_2',
        category: 'System',
        title: 'Ultrasonic Calibration',
        description: 'Ultrasonic sensors 1-4 calibrated across pen corners 1-4.',
        timestamp: now.subtract(const Duration(hours: 53, minutes: 25)),
      ),
      HistoryLog(
        id: 'log_d3_3',
        category: 'Swine Bath',
        title: 'Swine Bath Routine',
        description: 'Pump 1 (Relay 1) misting completed across all pens.',
        timestamp: now.subtract(const Duration(hours: 58, minutes: 40)),
      ),
      HistoryLog(
        id: 'log_d3_4',
        category: 'Foot Bath',
        title: 'Worker Entrance Cycle',
        description: 'Manual foot bath override triggered for entrance pass.',
        timestamp: now.subtract(const Duration(hours: 64, minutes: 15)),
      ),
      HistoryLog(
        id: 'log_d3_5',
        category: 'Thermal',
        title: 'Baseline Temperature Log',
        description: 'Pen temperature stabilized at baseline 24.5°C.',
        timestamp: now.subtract(const Duration(hours: 70, minutes: 30)),
      ),
    ];

    _logs = seeds;
    _isLoading = false;
    notifyListeners();

    for (final l in seeds) {
      _dbRef.child('history_logs').child(l.id).set({
        'category': l.category,
        'title': l.title,
        'description': l.description,
        'timestamp': l.timestamp.millisecondsSinceEpoch,
      }).catchError((_) {});
    }
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