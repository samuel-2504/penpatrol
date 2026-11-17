class Schedule {
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
    this.intensity = 50.0,
    this.duration = 10.0,
    this.enabled = true,
  });
}
