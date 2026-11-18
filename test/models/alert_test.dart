import 'package:flutter_test/flutter_test.dart';
import 'package:penpatrol/models/alert.dart';

void main() {
  group('Alert.fromJson', () {
    test('parses Firebase epoch-millisecond timestamps', () {
      final timestamp = DateTime.utc(2025, 1, 2, 3, 4);

      final alert = Alert.fromJson({
        'id': 'firebase-alert',
        'title': 'Temperature warning',
        'timestamp': timestamp.millisecondsSinceEpoch,
        'severity': 'warning',
      });

      expect(alert.timestamp, timestamp.toLocal());
      expect(alert.severity, AlertSeverity.warning);
    });

    test('rejects records without a valid Firebase timestamp', () {
      expect(
        () => Alert.fromJson({
          'id': 'invalid-alert',
          'title': 'Invalid timestamp',
        }),
        throwsFormatException,
      );
    });
  });
}
