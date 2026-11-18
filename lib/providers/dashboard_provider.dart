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
  // Sensors
  bool ultrasonic1Conn = true;
  bool ultrasonic2Conn = true;
  bool ultrasonic3Conn = true;
  bool ultrasonic4Conn = true;
  bool tofConn = true;
  bool mlx90640Conn = true;

  // Corner Servos 1-4 (Corners of the pen)
  bool servo1Conn = true;
  bool servo2Conn = true;
  bool servo3Conn = true;
  bool servo4Conn = true;

  // Customized Servos with Ball Valve (Act as solenoid valves)
  bool servo5Conn = true; // Servo 5: Pump 1 to Pen
  bool servo6Conn = true; // Servo 6: Pump 2 to Tunnel
  bool servo7Conn = true; // Servo 7: Pump 2 to Foot Bath
  bool servo8Conn = true; // Servo 8: Pump 2 to Pen (Disinfection)

  // Pumps & Relays
  bool pump1Conn = true;  // Pump 1 (Relay 1)
  bool pump2Conn = true;  // Pump 2 (Relay 2)

  // Backward compatibility getters
  bool get pump1PenConn => pump1Conn;
  bool get pump2TunnelConn => pump2Conn;
  bool get pump1TunnelConn => pump2Conn;
  bool get valve1PenConn => servo5Conn;
  bool get valve2TunnelConn => servo6Conn;
  bool get valve3FBathConn => servo7Conn;
  bool get valve4PenConn => servo8Conn;
  bool get ultrasonic5Conn => tofConn;
  bool get pir1Conn => ultrasonic1Conn;
  bool get pir2Conn => ultrasonic2Conn;
  bool get pir3Conn => ultrasonic3Conn;
  bool get pir4Conn => ultrasonic4Conn;
  bool get pir5Conn => tofConn;

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
        
        // Sensors
        ultrasonic1Conn = ((data['ultrasonic_1'] ?? data['pir_1']) as bool?) ?? true;
        ultrasonic2Conn = ((data['ultrasonic_2'] ?? data['pir_2']) as bool?) ?? true;
        ultrasonic3Conn = ((data['ultrasonic_3'] ?? data['pir_3']) as bool?) ?? true;
        ultrasonic4Conn = ((data['ultrasonic_4'] ?? data['pir_4']) as bool?) ?? true;
        tofConn = ((data['tof'] ??
                data['vl53l1x'] ??
                data['tof_vl53l1x'] ??
                data['ultrasonic_5'] ??
                data['pir_5']) as bool?) ??
            true;
        mlx90640Conn = (data['mlx90640'] as bool?) ?? true;

        // Corner Servos 1-4 (Corners of the pen)
        servo1Conn = ((data['servo_1'] ?? data['servo1']) as bool?) ?? true;
        servo2Conn = ((data['servo_2'] ?? data['servo2']) as bool?) ?? true;
        servo3Conn = ((data['servo_3'] ?? data['servo3']) as bool?) ?? true;
        servo4Conn = ((data['servo_4'] ?? data['servo4']) as bool?) ?? true;

        // Ball Valve Servos 5-8 (Solenoid valves)
        servo5Conn = ((data['servo_5'] ?? data['servo5'] ?? data['valve1_pen']) as bool?) ?? true;
        servo6Conn = ((data['servo_6'] ?? data['servo6'] ?? data['valve2_tunnel']) as bool?) ?? true;
        servo7Conn = ((data['servo_7'] ?? data['servo7'] ?? data['valve3_fBath']) as bool?) ?? true;
        servo8Conn = ((data['servo_8'] ?? data['servo8'] ?? data['valve4_pen'] ?? data['pump8']) as bool?) ?? true;

        // Pumps (Relays 1 & 2)
        pump1Conn = ((data['pump_1'] ?? data['pump1'] ?? data['pump1_pen'] ?? data['relay_1'] ?? data['relay1']) as bool?) ?? true;
        pump2Conn = ((data['pump_2'] ?? data['pump2'] ?? data['pump2_tunnel'] ?? data['relay_2'] ?? data['relay2']) as bool?) ?? true;

        notifyListeners();
      } else {
        // Seed default hardware status to Firebase so RTDB holds the master state
        _dbRef.child('hardware_status').set({
          'mlx90640': true,
          'ultrasonic_1': true,
          'ultrasonic_2': true,
          'ultrasonic_3': true,
          'ultrasonic_4': true,
          'tof': true,
          'servo_1': true,
          'servo_2': true,
          'servo_3': true,
          'servo_4': true,
          'servo_5': true,
          'servo_6': true,
          'servo_7': true,
          'servo_8': true,
          'pump_1': true,
          'pump_2': true,
        }).catchError((_) {});
      }
    });

    // 2. Listen to thermal_sensor node
    _thermalSub = _dbRef.child('thermal_sensor').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        temperature = (data['avg_temp'] as num?)?.toDouble() ?? temperature;
        humidity = (data['humidity'] as num?)?.toDouble() ?? humidity;

        final rawGrid = (data['grid'] ?? data['frame']) as List?;
        if (rawGrid != null && rawGrid.isNotEmpty) {
          thermalGrid = rawGrid
              .map((e) => (e as num).toDouble())
              .toList();
        }
        notifyListeners();
      } else {
        // Seed initial live thermal data to Firebase so the camera feed is immediately available
        _seedThermalToFirebase();
      }
    });

    // 3. Listen to disinfection_tunnel status
    _tunnelSub = _dbRef.child('controls/disinfection_tunnel').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        tunnelOn = (data['spray_active'] as bool?) ?? false;
        notifyListeners();
      } else {
        _dbRef.child('controls/disinfection_tunnel').set({
          'spray_active': false,
          'pump1_tunnel': false,
          'valve2_tunnel': 0,
        }).catchError((_) {});
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
      } else {
        _dbRef.child('controls/foot_bath').set({
          'active': false,
          'pump2_tunnel': false,
          'valve3_fBath': 0,
        }).catchError((_) {});
      }
    });

    // 5. Listen to swine_bath status
    _swineBathSub = _dbRef.child('controls/swine_bath').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        swineBathOn = (data['pump1_pen'] as bool?) ?? false; // True if pump is on
        notifyListeners();
      } else {
        _dbRef.child('controls/swine_bath').set({
          'pump1_pen': false,
          'valve1_pen': 0,
          'intensity_percent': 0.0,
          'duration_minutes': 0.0,
        }).catchError((_) {});
      }
    });
  }

  void _seedThermalToFirebase() {
    final List<double> defaultGrid = List.generate(768, (i) {
      final x = i % 32;
      final y = i ~/ 32;
      final d1 = (x - 10) * (x - 10) + (y - 12) * (y - 12);
      final d2 = (x - 22) * (x - 22) + (y - 8) * (y - 8);
      double temp = 26.5 + (i % 7) * 0.15;
      if (d1 < 36) temp += (36 - d1) * 0.32;
      if (d2 < 25) temp += (25 - d2) * 0.45;
      return double.parse(temp.toStringAsFixed(1));
    });

    _dbRef.child('thermal_sensor').set({
      'avg_temp': 28.6,
      'humidity': 62.0,
      'grid': defaultGrid,
      'timestamp': ServerValue.timestamp,
    }).catchError((_) {});
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
        tofConn &&
        mlx90640Conn;
    return allConnected ? 'READY' : 'OFFLINE';
  }

  String get servosStatus {
    final allConnected = servo1Conn &&
        servo2Conn &&
        servo3Conn &&
        servo4Conn &&
        servo5Conn &&
        servo6Conn &&
        servo7Conn &&
        servo8Conn;
    return allConnected ? 'READY' : 'OFFLINE';
  }

  String get pumpsStatus {
    return (pump1Conn && pump2Conn) ? 'READY' : 'OFFLINE';
  }

  int get onlineSensorsCount => [
        mlx90640Conn,
        ultrasonic1Conn,
        ultrasonic2Conn,
        ultrasonic3Conn,
        ultrasonic4Conn,
        tofConn,
      ].where((c) => c).length;

  int get onlineServosCount => [
        servo1Conn,
        servo2Conn,
        servo3Conn,
        servo4Conn,
        servo5Conn,
        servo6Conn,
        servo7Conn,
        servo8Conn,
      ].where((c) => c).length;

  int get onlinePumpsCount => [
        pump1Conn,
        pump2Conn,
      ].where((c) => c).length;

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