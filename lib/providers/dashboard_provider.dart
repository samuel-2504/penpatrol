import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://pen-patrol-db-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();

  StreamSubscription<DatabaseEvent>? _thermalSub;
  StreamSubscription<DatabaseEvent>? _tunnelSub;
  StreamSubscription<DatabaseEvent>? _footBathSub;
  StreamSubscription<DatabaseEvent>? _swineBathSub;
  StreamSubscription<DatabaseEvent>? _hardwareSub;

  Timer? _footBathTimer;
  int footBathRemainingSeconds = 0;

  // --- HARDWARE CONNECTION STATUSES ---
  bool pump1PenConn = false;
  bool valve1PenConn = false;
  bool pump2TunnelConn = false;
  bool valve2TunnelConn = false;
  bool valve3FBathConn = false;
  bool pump1TunnelConn = false;

  bool ultrasonic1Conn = false;
  bool ultrasonic2Conn = false;
  bool ultrasonic3Conn = false;
  bool ultrasonic4Conn = false;
  bool ultrasonic5Conn = false;
  bool mlx90640Conn = false;

  // Backward compatibility getters
  bool get pir1Conn => ultrasonic1Conn;
  bool get pir2Conn => ultrasonic2Conn;
  bool get pir3Conn => ultrasonic3Conn;
  bool get pir4Conn => ultrasonic4Conn;
  bool get pir5Conn => ultrasonic5Conn;

  // --- OPERATIONAL STATES ---
  bool footBathOn = false;
  bool swineBathOn = false;
  bool tunnelOn = false;

  double temperature = 0.0;
  double humidity = 0.0;
  List<double> thermalGrid = [];

  DashboardProvider() {
    _listenToFirebase();
  }

  void _listenToFirebase() {
    // 1. Listen to hardware connection states from Arduino
    _hardwareSub = _dbRef.child('hardware_status').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        pump1PenConn = (data['pump1_pen'] as bool?) ?? false;
        valve1PenConn = (data['valve1_pen'] as bool?) ?? false;
        pump2TunnelConn = (data['pump2_tunnel'] as bool?) ?? false;
        valve2TunnelConn = (data['valve2_tunnel'] as bool?) ?? false;
        valve3FBathConn = (data['valve3_fBath'] as bool?) ?? false;
        pump1TunnelConn = (data['pump1_tunnel'] as bool?) ?? false;

        ultrasonic1Conn = ((data['ultrasonic_1'] ?? data['pir_1']) as bool?) ?? false;
        ultrasonic2Conn = ((data['ultrasonic_2'] ?? data['pir_2']) as bool?) ?? false;
        ultrasonic3Conn = ((data['ultrasonic_3'] ?? data['pir_3']) as bool?) ?? false;
        ultrasonic4Conn = ((data['ultrasonic_4'] ?? data['pir_4']) as bool?) ?? false;
        ultrasonic5Conn = ((data['ultrasonic_5'] ?? data['pir_5']) as bool?) ?? false;
        mlx90640Conn = (data['mlx90640'] as bool?) ?? false;

        notifyListeners();
      }
    });

    // 2. Listen to thermal_sensor node
    _thermalSub = _dbRef.child('thermal_sensor').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        temperature = (data['avg_temp'] as num?)?.toDouble() ?? temperature;
        humidity = (data['humidity'] as num?)?.toDouble() ?? humidity;

        final rawGrid = (data['grid'] ?? data['frame']) as List?;
        if (rawGrid != null) {
          thermalGrid = rawGrid
              .map((e) => (e as num).toDouble())
              .toList();
        }
        notifyListeners();
      }
    });

    // 3. Listen to disinfection_tunnel status
    _tunnelSub = _dbRef.child('controls/disinfection_tunnel').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        tunnelOn = (data['spray_active'] as bool?) ?? false;
        notifyListeners();
      }
    });

    // 4. Listen to foot_bath status
    _footBathSub = _dbRef.child('controls/foot_bath').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final bool active = (data['active'] as bool?) ?? false;
        if (!active && footBathOn && _footBathTimer != null) {
          _footBathTimer?.cancel();
          _footBathTimer = null;
          footBathRemainingSeconds = 0;
        }
        footBathOn = active;
        notifyListeners();
      }
    });

    // 5. Listen to swine_bath status
    _swineBathSub = _dbRef.child('controls/swine_bath').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        swineBathOn = (data['pump1_pen'] as bool?) ?? false; // True if pump is on
        notifyListeners();
      }
    });
  }

  // --- COMPONENT STATUS GETTERS ---

  String get footBathStatus {
    if (footBathOn) return 'ACTIVE';
    return (valve3FBathConn && pump2TunnelConn) ? 'READY' : 'OFFLINE';
  }

  String get swineBathStatus {
    if (swineBathOn) return 'ACTIVE';
    return (valve1PenConn && pump1PenConn) ? 'READY' : 'OFFLINE';
  }

  String get tunnelStatus {
    if (tunnelOn) return 'ACTIVE';
    return (valve2TunnelConn && pump2TunnelConn) ? 'READY' : 'OFFLINE';
  }

  String get sensorsStatus {
    final allConnected = ultrasonic1Conn &&
        ultrasonic2Conn &&
        ultrasonic3Conn &&
        ultrasonic4Conn &&
        ultrasonic5Conn &&
        mlx90640Conn;
    return allConnected ? 'READY' : 'OFFLINE';
  }

  // --- CONTROL COMMANDS SENT TO ARDUINO VIA FIREBASE ---

  Future<void> triggerFootBath({int seconds = 10}) async {
    _footBathTimer?.cancel();
    footBathOn = true;
    footBathRemainingSeconds = seconds;
    notifyListeners();

    try {
      await _dbRef.child('controls/foot_bath').set({
        'active': true,
        'pump2_tunnel': true,
        'valve3_fBath': 180, // 180 degrees customized servo
      });
    } catch (e) {
      debugPrint('Error triggering foot bath: $e');
    }

    _footBathTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (footBathRemainingSeconds > 1) {
        footBathRemainingSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        _footBathTimer = null;
        footBathRemainingSeconds = 0;
        await stopFootBath();
      }
    });
  }

  Future<void> stopFootBath() async {
    _footBathTimer?.cancel();
    _footBathTimer = null;
    footBathRemainingSeconds = 0;
    footBathOn = false;
    notifyListeners();

    try {
      await _dbRef.child('controls/foot_bath').set({
        'active': false,
        'pump2_tunnel': false,
        'valve3_fBath': 0,
      });
    } catch (e) {
      debugPrint('Error stopping foot bath: $e');
    }
  }

  Future<void> toggleFootBath(bool v) async {
    if (v) {
      await triggerFootBath(seconds: 10);
    } else {
      await stopFootBath();
    }
  }

  // Trigger 5-Second System Diagnostic Test
  Future<void> setSystemTestStatus(String systemName, bool isOn) async {
    if (systemName == 'Swine Bath') {
      await _dbRef.child('controls/swine_bath').update({
        'test_active': isOn,
        'pump1_pen': isOn,
        'valve1_pen': isOn ? 180 : 0,
        'servo1': isOn ? 180 : 0,
        'servo2': isOn ? 180 : 0,
        'servo3': isOn ? 180 : 0,
        'servo4': isOn ? 180 : 0,
      });
    } else if (systemName == 'Disinfection Tunnel') {
      await _dbRef.child('controls/disinfection_tunnel').update({
        'test_active': isOn,
        'spray_active': isOn,
        'pump1_tunnel': isOn,
        'valve2_tunnel': isOn ? 180 : 0,
      });
    } else if (systemName == 'Foot Bath') {
      await _dbRef.child('controls/foot_bath').update({
        'test_active': isOn,
        'active': isOn,
        'pump2_tunnel': isOn,
        'valve3_fBath': isOn ? 180 : 0,
      });
    }
  }

  @override
  void dispose() {
    _footBathTimer?.cancel();
    _hardwareSub?.cancel();
    _thermalSub?.cancel();
    _tunnelSub?.cancel();
    _footBathSub?.cancel();
    _swineBathSub?.cancel();
    super.dispose();
  }
}