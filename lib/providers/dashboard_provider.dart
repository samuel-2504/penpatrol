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
  bool ultrasonic1Conn = false;
  bool ultrasonic2Conn = false;
  bool ultrasonic3Conn = false;
  bool ultrasonic4Conn = false;
  bool tofConn = false;
  bool mlx90640Conn = false;

  // Corner Servos 1-4 (Corners of the pen)
  bool servo1Conn = false;
  bool servo2Conn = false;
  bool servo3Conn = false;
  bool servo4Conn = false;

  // Customized Servos with Ball Valve (Act as solenoid valves)
  bool servo5Conn = false; // Servo 5: Pump 1 to Pen
  bool servo6Conn = false; // Servo 6: Pump 2 to Tunnel
  bool servo7Conn = false; // Servo 7: Pump 2 to Foot Bath
  bool servo8Conn = false; // Servo 8: Pump 2 to Pen (Disinfection)

  // Pumps & Relays
  bool pump1Conn = false; // Pump 1 (Relay 1)
  bool pump2Conn = false; // Pump 2 (Relay 2)

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
  bool hasThermalData = false;
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
        ultrasonic1Conn =
            ((data['ultrasonic_1'] ?? data['pir_1']) as bool?) ?? false;
        ultrasonic2Conn =
            ((data['ultrasonic_2'] ?? data['pir_2']) as bool?) ?? false;
        ultrasonic3Conn =
            ((data['ultrasonic_3'] ?? data['pir_3']) as bool?) ?? false;
        ultrasonic4Conn =
            ((data['ultrasonic_4'] ?? data['pir_4']) as bool?) ?? false;
        tofConn = ((data['tof'] ??
                data['vl53l1x'] ??
                data['tof_vl53l1x'] ??
                data['ultrasonic_5'] ??
                data['pir_5']) as bool?) ??
            false;
        mlx90640Conn = (data['mlx90640'] as bool?) ?? false;

        // Corner Servos 1-4 (Corners of the pen)
        servo1Conn = ((data['servo_1'] ?? data['servo1']) as bool?) ?? false;
        servo2Conn = ((data['servo_2'] ?? data['servo2']) as bool?) ?? false;
        servo3Conn = ((data['servo_3'] ?? data['servo3']) as bool?) ?? false;
        servo4Conn = ((data['servo_4'] ?? data['servo4']) as bool?) ?? false;

        // Ball Valve Servos 5-8 (Solenoid valves)
        servo5Conn = ((data['servo_5'] ?? data['servo5'] ?? data['valve1_pen'])
                as bool?) ??
            false;
        servo6Conn = ((data['servo_6'] ??
                data['servo6'] ??
                data['valve2_tunnel']) as bool?) ??
            false;
        servo7Conn = ((data['servo_7'] ??
                data['servo7'] ??
                data['valve3_fBath']) as bool?) ??
            false;
        servo8Conn = ((data['servo_8'] ??
                data['servo8'] ??
                data['valve4_pen'] ??
                data['pump8']) as bool?) ??
            false;

        // Pumps (Relays 1 & 2)
        pump1Conn = ((data['pump_1'] ??
                data['pump1'] ??
                data['pump1_pen'] ??
                data['relay_1'] ??
                data['relay1']) as bool?) ??
            false;
        pump2Conn = ((data['pump_2'] ??
                data['pump2'] ??
                data['pump2_tunnel'] ??
                data['relay_2'] ??
                data['relay2']) as bool?) ??
            false;

        notifyListeners();
      } else {
        ultrasonic1Conn = false;
        ultrasonic2Conn = false;
        ultrasonic3Conn = false;
        ultrasonic4Conn = false;
        tofConn = false;
        mlx90640Conn = false;
        servo1Conn = false;
        servo2Conn = false;
        servo3Conn = false;
        servo4Conn = false;
        servo5Conn = false;
        servo6Conn = false;
        servo7Conn = false;
        servo8Conn = false;
        pump1Conn = false;
        pump2Conn = false;
        notifyListeners();
      }
    });

    // 2. Listen to thermal_sensor node
    _thermalSub = _dbRef.child('thermal_sensor').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        temperature = (data['avg_temp'] as num?)?.toDouble() ?? temperature;
        humidity = (data['humidity'] as num?)?.toDouble() ?? humidity;
        hasThermalData = data['avg_temp'] is num;

        final rawGrid = (data['grid'] ?? data['frame']) as List?;
        if (rawGrid != null && rawGrid.isNotEmpty) {
          thermalGrid = rawGrid.map((e) => (e as num).toDouble()).toList();
        }
        notifyListeners();
      } else {
        temperature = 0;
        humidity = 0;
        hasThermalData = false;
        thermalGrid = [];
        notifyListeners();
      }
    });

    // 3. Listen to disinfection_tunnel status
    _tunnelSub =
        _dbRef.child('controls/disinfection_tunnel').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        tunnelOn = (data['spray_active'] as bool?) ?? false;
        notifyListeners();
      } else {
        tunnelOn = false;
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
      } else {
        footBathOn = false;
        notifyListeners();
      }
    });

    // 5. Listen to swine_bath status
    _swineBathSub = _dbRef.child('controls/swine_bath').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        swineBathOn =
            (data['pump1_pen'] as bool?) ?? false; // True if pump is on
        notifyListeners();
      } else {
        swineBathOn = false;
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
