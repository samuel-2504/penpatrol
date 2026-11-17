import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  StreamSubscription<DatabaseEvent>? _thermalSub;
  StreamSubscription<DatabaseEvent>? _tunnelSub;
  StreamSubscription<DatabaseEvent>? _footBathSub;
  StreamSubscription<DatabaseEvent>? _swineBathSub;
  StreamSubscription<DatabaseEvent>? _hardwareSub;

  // --- HARDWARE CONNECTION STATUSES ---
  bool pump1PenConn = false;
  bool valve1PenConn = false;
  bool pump2TunnelConn = false;
  bool valve2TunnelConn = false;
  bool valve3FBathConn = false;
  bool pump1TunnelConn = false;

  bool pir1Conn = false;
  bool pir2Conn = false;
  bool pir3Conn = false;
  bool pir4Conn = false;
  bool pir5Conn = false;
  bool mlx90640Conn = false;

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

        pir1Conn = (data['pir_1'] as bool?) ?? false;
        pir2Conn = (data['pir_2'] as bool?) ?? false;
        pir3Conn = (data['pir_3'] as bool?) ?? false;
        pir4Conn = (data['pir_4'] as bool?) ?? false;
        pir5Conn = (data['pir_5'] as bool?) ?? false;
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

        if (data['grid'] is List) {
          thermalGrid = (data['grid'] as List)
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
        footBathOn = (data['active'] as bool?) ?? false;
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
    final allConnected = pir1Conn && pir2Conn && pir3Conn && pir4Conn && pir5Conn && mlx90640Conn;
    return allConnected ? 'READY' : 'OFFLINE';
  }

  // --- CONTROL COMMANDS SENT TO ARDUINO VIA FIREBASE ---

  Future<void> toggleFootBath(bool v) async {
    footBathOn = v;
    notifyListeners();
    await _dbRef.child('controls/foot_bath').set({
      'active': v,
      'pump2_tunnel': v,
      'valve3_fBath': v ? 180 : 0, // 180 degrees customized servo
    });
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
    _hardwareSub?.cancel();
    _thermalSub?.cancel();
    _tunnelSub?.cancel();
    _footBathSub?.cancel();
    _swineBathSub?.cancel();
    super.dispose();
  }
}