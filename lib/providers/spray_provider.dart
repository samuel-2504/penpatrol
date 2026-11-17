import 'dart:async';
import 'package:flutter/material.dart';

enum SprayMode { manual, scheduled, auto }

extension SprayModeLabel on SprayMode {
  String get label {
    switch (this) {
      case SprayMode.manual:
        return 'Manual';
      case SprayMode.scheduled:
        return 'Scheduled';
      case SprayMode.auto:
        return 'Auto';
    }
  }
}

class SprayProvider extends ChangeNotifier {
  SprayMode mode = SprayMode.manual;
  bool isRunning = false;
  double progress = 0.0;
  double intensity = 50.0;
  double duration = 10.0; // minutes
  Timer? _timer;

  void setMode(SprayMode m) {
    mode = m;
    notifyListeners();
  }

  void setIntensity(double v) {
    intensity = v;
    notifyListeners();
  }

  void setDuration(double v) {
    duration = v;
    notifyListeners();
  }

  void start() {
    if (isRunning) return;
    isRunning = true;
    progress = 0.0;
    notifyListeners();
    const tick = Duration(milliseconds: 300);
    _timer = Timer.periodic(tick, (timer) {
      progress += 0.02;
      if (progress >= 1.0) {
        progress = 1.0;
        isRunning = false;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  void stop() {
    _timer?.cancel();
    isRunning = false;
    progress = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
