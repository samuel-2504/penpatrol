enum AlertSeverity { info, warning, critical }

class Alert {
  String id;
  String title;
  String subtitle; // Added missing property
  DateTime timestamp;
  AlertSeverity severity;
  bool read;

  Alert({
    required this.id,
    required this.title,
    required this.subtitle, // Required in constructor
    required this.timestamp,
    required this.severity,
    this.read = false,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Alert',
      subtitle: json['subtitle']?.toString() ?? '', // Parse subtitle
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString()) 
          : DateTime.now(),
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.info,
      ),
      read: json['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle, // Save subtitle to Firebase
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
      'read': read,
    };
  }
}