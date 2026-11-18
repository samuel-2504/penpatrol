import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/app_theme.dart';
import '../widgets/title_bar.dart';

class ThermalViewScreen extends StatefulWidget {
  const ThermalViewScreen({super.key});

  @override
  State<ThermalViewScreen> createState() => _ThermalViewScreenState();
}

class _ThermalViewScreenState extends State<ThermalViewScreen> {
  List<double> _thermalData = [];
  DateTime? _lastTimestamp;
  ui.Image? _thermalImage;
  StreamSubscription<DatabaseEvent>? _thermalSubscription;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToFirebaseStream();
  }

  void _connectToFirebaseStream() {
    final DatabaseReference ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://pen-patrol-db-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref('thermal_sensor');

    _thermalSubscription = ref.onValue.listen(
      (DatabaseEvent event) {
        if (event.snapshot.value != null && mounted) {
          try {
            final Map<dynamic, dynamic> dataMap =
                event.snapshot.value as Map<dynamic, dynamic>;

            final List<dynamic>? rawFrame =
                (dataMap['frame'] ?? dataMap['grid']) as List<dynamic>?;
            final num? timestampRaw = dataMap['timestamp'] as num?;

            if (rawFrame != null && rawFrame.isNotEmpty) {
              final parsedData =
                  rawFrame.map((e) => (e as num).toDouble()).toList();

              final dateTime = timestampRaw == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(timestampRaw.toInt());

              setState(() {
                _thermalData = parsedData;
                _lastTimestamp = dateTime;
                _isConnected = true;
              });

              _generateRawImage(parsedData);
            }
          } catch (e) {
            debugPrint('Error parsing thermal data: $e');
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      },
    );
  }

  Future<void> _generateRawImage(List<double> data) async {
    if (data.length != 768) return;

    double tMin = data.reduce(min);
    double tMax = data.reduce(max);
    if (tMax == tMin) tMax = tMin + 1; // Prevent division by zero

    // Create a byte array for 32x24 pixels (4 bytes per pixel: R, G, B, A)
    final Uint8List pixels = Uint8List(32 * 24 * 4);

    for (int i = 0; i < 768; i++) {
      double t = data[i];
      double normalized = (t - tMin) / (tMax - tMin);
      normalized = normalized.clamp(0.0, 1.0);

      // Color mapping
      Color pixelColor;
      if (normalized < 0.5) {
        pixelColor = Color.lerp(Colors.blue, Colors.green, normalized * 2)!;
      } else {
        pixelColor =
            Color.lerp(Colors.green, Colors.red, (normalized - 0.5) * 2)!;
      }

      // Populate the RGBA array
      final int offset = i * 4;
      pixels[offset] = (pixelColor.r * 255.0).round().clamp(0, 255);
      pixels[offset + 1] = (pixelColor.g * 255.0).round().clamp(0, 255);
      pixels[offset + 2] = (pixelColor.b * 255.0).round().clamp(0, 255);
      pixels[offset + 3] = 255; // Alpha (fully opaque)
    }

    // Decode raw bytes into a Flutter Image
    ui.decodeImageFromPixels(
      pixels,
      32, // MLX90640 width
      24, // MLX90640 height
      ui.PixelFormat.rgba8888,
      (ui.Image img) {
        if (mounted) {
          setState(() {
            _thermalImage = img;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _thermalSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? tMin =
        _thermalData.isNotEmpty ? _thermalData.reduce(min) : null;
    final double? tMax =
        _thermalData.isNotEmpty ? _thermalData.reduce(max) : null;
    final double? tAvg = _thermalData.isNotEmpty
        ? _thermalData.reduce((a, b) => a + b) / _thermalData.length
        : null;

    String timeString = '--';
    if (_lastTimestamp != null) {
      timeString = _lastTimestamp!.toLocal().toString().split('.')[0];
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: TitleBar(
        screenName: 'Thermal Analysis',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.extras.border,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.hardEdge,
              child: _thermalImage == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Waiting for Firebase Thermal Feed...'),
                        ],
                      ),
                    )
                  : SizedBox.expand(
                      child: RawImage(
                        image: _thermalImage,
                        fit: BoxFit.fill,
                        // Disabled interpolation for a raw pixel grid/chess pattern look
                        filterQuality: FilterQuality.none,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sensor Diagnostics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.extras.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.extras.border),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.local_fire_department,
                    label: 'Highest Temp',
                    value: '${tMax?.toStringAsFixed(1) ?? '--'} °C',
                    valueColor: Colors.redAccent,
                  ),
                  Divider(height: 24, color: context.extras.border),
                  _InfoRow(
                    icon: Icons.ac_unit,
                    label: 'Lowest Temp',
                    value: '${tMin?.toStringAsFixed(1) ?? '--'} °C',
                    valueColor: Colors.lightBlue,
                  ),
                  Divider(height: 24, color: context.extras.border),
                  _InfoRow(
                    icon: Icons.thermostat,
                    label: 'Average Temp',
                    value: '${tAvg?.toStringAsFixed(1) ?? '--'} °C',
                    valueColor: Colors.greenAccent,
                  ),
                  Divider(height: 24, color: context.extras.border),
                  _InfoRow(
                    icon: Icons.access_time_filled,
                    label: 'Timestamp',
                    value: timeString,
                    valueColor: Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.white,
                  ),
                  Divider(height: 24, color: context.extras.border),
                  _InfoRow(
                    icon: Icons.sync,
                    label: 'Feed Status',
                    value: _isConnected ? 'LIVE • FIREBASE' : 'OFFLINE',
                    valueColor:
                        _isConnected ? Colors.tealAccent : Colors.orangeAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;

    return Row(
      children: [
        Icon(icon, size: 22, color: muted),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
