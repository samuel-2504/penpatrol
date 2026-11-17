class HistoryLog {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String category; // e.g. Spray, Alert, System, Schedule

  HistoryLog({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.category,
  });
}
