class Schedule {
  static const minDurationMinutes = 1.0;
  static const maxDurationMinutes = 10.0;
  static const defaultDurationMinutes = 5.0;
  static const defaultIntensity = 55 / 90 * 100;

  final String id;
  final String title;
  final String time;
  final List<String> selectedDays;
  final double intensity;
  final double duration;
  bool enabled;

  Schedule({
    required this.id,
    required this.title,
    required this.time,
    required this.selectedDays,
    this.intensity = defaultIntensity,
    this.duration = defaultDurationMinutes,
    this.enabled = true,
  });
}
