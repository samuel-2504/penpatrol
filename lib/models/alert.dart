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
    final timestampValue = json['timestamp'];
    final DateTime? timestamp;
    if (timestampValue is num) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue.toInt());
    } else if (timestampValue is String) {
      timestamp = DateTime.tryParse(timestampValue);
    } else {
      timestamp = null;
    }

    if (timestamp == null) {
      throw const FormatException('Alert timestamp is missing or invalid.');
    }

    return Alert(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Alert',
      subtitle: json['subtitle']?.toString() ?? '',
      timestamp: timestamp,
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.info,
      ),
      read: json['read'] is bool ? json['read'] as bool : false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
      'read': read,
    };
  }
}
