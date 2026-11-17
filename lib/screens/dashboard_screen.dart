import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/alerts_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/title_bar.dart';
import '../widgets/status_pill.dart';
import '../models/alert.dart';
import 'thermal_view_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final alerts = context.watch<AlertsProvider>();
    final muted = context.extras.muted;
    final pad = Responsive.pagePadding(context);
    final activeSensors = [
      dash.mlx90640Conn,
      dash.pir1Conn,
      dash.pir2Conn,
      dash.pir3Conn,
      dash.pir4Conn,
      dash.pir5Conn,
    ].where((c) => c).length;

    return Scaffold(
      appBar: const TitleBar(
        screenName: 'Dashboard',
      ),
      body: ResponsiveScaffoldBody(
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: [
            Text(
              'Farm Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Live status of all connected systems',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Status pills - 3 rows for even presentation
            StatusPill(label: 'Foot Bath', status: dash.footBathStatus),
            const SizedBox(height: 10),
            StatusPill(label: 'Swine Bath', status: dash.swineBathStatus),
            const SizedBox(height: 10),
            StatusPill(label: 'Tunnel', status: dash.tunnelStatus),

            const SizedBox(height: 24),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thermal Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.thermostat_rounded,
                          label: 'Temperature',
                          value: '${dash.temperature.toStringAsFixed(1)}°C',
                          color: dash.temperature > 38
                              ? AppColors.red
                              : AppColors.teal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // LIVE THERMAL VIEW PREVIEW FROM FIREBASE
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.extras.border, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    // Pass the data down so the Stateful widget can react to changes
                    child: ThermalMapPreview(thermalData: dash.thermalGrid),
                  ),

                  const SizedBox(height: 12),

                  // EXPAND BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.teal, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen_rounded, color: AppColors.teal),
                      label: const Text(
                        'Detailed Thermal View',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ThermalViewScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // --- INITIATE FOOTBATH BUTTON CARD ---
            const SizedBox(height: 16),
            _Card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.water_drop_rounded,
                              color: AppColors.teal),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Initiate Footbath',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manual override control',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Builder(builder: (context) {
                    final bool isActive = dash.footBathOn;

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive
                            ? AppColors.teal
                            : muted.withValues(alpha: 0.15),
                        foregroundColor: isActive ? Colors.white : muted,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        context.read<DashboardProvider>().toggleFootBath(!isActive);
                      },
                      child: Text(
                        isActive ? 'ON' : 'OFF',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // --- SENSORS SECTION ---
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sensors_rounded,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sensors',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$activeSensors of 6 online',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (dash.sensorsStatus == 'READY'
                                      ? AppColors.teal
                                      : AppColors.amber)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (dash.sensorsStatus == 'READY'
                                        ? AppColors.teal
                                        : AppColors.amber)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              dash.sensorsStatus,
                              style: TextStyle(
                                color: dash.sensorsStatus == 'READY'
                                    ? AppColors.teal
                                    : AppColors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14),
                            color: muted,
                            tooltip: 'Sensor Diagnostics',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SensorStatusScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: context.extras.border, height: 1),
                  const SizedBox(height: 8),
                  if (Responsive.isMobile(context))
                    Column(
                      children: [
                        _SensorTile(
                          title: 'Thermal Camera',
                          subtitle: 'MLX90640',
                          isConnected: dash.mlx90640Conn,
                          icon: Icons.videocam_rounded,
                        ),
                        _SensorTile(
                          title: 'PIR Sensor 1',
                          subtitle: 'Pen 1',
                          isConnected: dash.pir1Conn,
                          icon: Icons.motion_photos_on_rounded,
                        ),
                        _SensorTile(
                          title: 'PIR Sensor 2',
                          subtitle: 'Pen 2',
                          isConnected: dash.pir2Conn,
                          icon: Icons.motion_photos_on_rounded,
                        ),
                        _SensorTile(
                          title: 'PIR Sensor 3',
                          subtitle: 'Pen 3',
                          isConnected: dash.pir3Conn,
                          icon: Icons.motion_photos_on_rounded,
                        ),
                        _SensorTile(
                          title: 'PIR Sensor 4',
                          subtitle: 'Pen 4',
                          isConnected: dash.pir4Conn,
                          icon: Icons.motion_photos_on_rounded,
                        ),
                        _SensorTile(
                          title: 'PIR Sensor 5',
                          subtitle: 'Corridor',
                          isConnected: dash.pir5Conn,
                          icon: Icons.motion_photos_on_rounded,
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _SensorTile(
                                title: 'Thermal Camera',
                                subtitle: 'MLX90640',
                                isConnected: dash.mlx90640Conn,
                                icon: Icons.videocam_rounded,
                              ),
                              _SensorTile(
                                title: 'PIR Sensor 1',
                                subtitle: 'Pen 1',
                                isConnected: dash.pir1Conn,
                                icon: Icons.motion_photos_on_rounded,
                              ),
                              _SensorTile(
                                title: 'PIR Sensor 2',
                                subtitle: 'Pen 2',
                                isConnected: dash.pir2Conn,
                                icon: Icons.motion_photos_on_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _SensorTile(
                                title: 'PIR Sensor 3',
                                subtitle: 'Pen 3',
                                isConnected: dash.pir3Conn,
                                icon: Icons.motion_photos_on_rounded,
                              ),
                              _SensorTile(
                                title: 'PIR Sensor 4',
                                subtitle: 'Pen 4',
                                isConnected: dash.pir4Conn,
                                icon: Icons.motion_photos_on_rounded,
                              ),
                              _SensorTile(
                                title: 'PIR Sensor 5',
                                subtitle: 'Corridor',
                                isConnected: dash.pir5Conn,
                                icon: Icons.motion_photos_on_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // --- TEST SPRAY CARD ---
            const SizedBox(height: 16),
            _Card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.science_rounded,
                              color: AppColors.amber),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diagnostics',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Run 5-second system test spray',
                                style: TextStyle(color: muted, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.amber, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TestSprayScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'TEST',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.amber),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Alerts',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        '${alerts.alerts.length}',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (alerts.alerts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.teal, size: 36),
                            const SizedBox(height: 8),
                            Text('No active alerts',
                                style: TextStyle(color: muted)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...alerts.alerts.take(3).map(
                          (a) => _MiniAlertRow(alert: a),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// INTERACTIVE SENSORS STATUS SCREEN
// ==========================================
class SensorStatusScreen extends StatelessWidget {
  const SensorStatusScreen({super.key});

  Widget _buildSensorTile(BuildContext context, String title, bool isConnected) {
    final muted = context.extras.muted;
    final color = isConnected ? AppColors.teal : AppColors.red;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.extras.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.extras.border),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(
                  isConnected ? 'Online & Active' : 'Offline / Disconnected',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final pad = Responsive.pagePadding(context);

    return Scaffold(
      appBar: TitleBar(
        screenName: 'Sensor Diagnostics',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: [
            _buildSensorTile(context, 'Thermal Camera (MLX90640)', dash.mlx90640Conn),
            _buildSensorTile(context, 'PIR Sensor 1 (Pen 1)', dash.pir1Conn),
            _buildSensorTile(context, 'PIR Sensor 2 (Pen 2)', dash.pir2Conn),
            _buildSensorTile(context, 'PIR Sensor 3 (Pen 3)', dash.pir3Conn),
            _buildSensorTile(context, 'PIR Sensor 4 (Pen 4)', dash.pir4Conn),
            _buildSensorTile(context, 'PIR Sensor 5 (Corridor)', dash.pir5Conn),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TEST SPRAY SCREEN WITH FIREBASE SYNC
// ==========================================
class TestSprayScreen extends StatefulWidget {
  const TestSprayScreen({super.key});

  @override
  State<TestSprayScreen> createState() => _TestSprayScreenState();
}

class _TestSprayScreenState extends State<TestSprayScreen> {
  String _selectedSystem = 'Swine Bath';
  final List<String> _systems = [
    'Swine Bath',
    'Disinfection Tunnel',
    'Foot Bath'
  ];

  bool _isTesting = false;
  double _progress = 0.0;

  void _startTest() async {
    setState(() {
      _isTesting = true;
      _progress = 0.0;
    });

    try {
      // 1. SIGNAL ARDUINO VIA FIREBASE TO START SPRAYING
      await context
          .read<DashboardProvider>()
          .setSystemTestStatus(_selectedSystem, true);

      // 2. RUN 5-SECOND PROGRESS BAR ANIMATION
      const int totalSteps = 50;
      for (int i = 1; i <= totalSteps; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        setState(() {
          _progress = i / totalSteps;
        });
      }

      // 3. SIGNAL ARDUINO VIA FIREBASE TO STOP SPRAYING
      if (mounted) {
        await context
            .read<DashboardProvider>()
            .setSystemTestStatus(_selectedSystem, false);
      }

      setState(() {
        _isTesting = false;
        _progress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_selectedSystem 5-second test completed.'),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_isTesting) {
          setState(() {
            _progress = 0.0;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isTesting = false;
        _progress = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error communicating with Firebase.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    final pad = Responsive.pagePadding(context);

    return Scaffold(
      appBar: TitleBar(
        screenName: 'Test Spray System',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Target System',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose which system to run a diagnostic spray on.',
                style: TextStyle(color: muted, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Radio List Selection
              Container(
                decoration: BoxDecoration(
                  color: context.extras.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.extras.border),
                ),
                child: Column(
                  children: _systems.map((system) {
                    final isSelected = _selectedSystem == system;
                    return RadioListTile<String>(
                      title: Text(system,
                          style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.teal : null)),
                      value: system,
                      // ignore: deprecated_member_use
                      groupValue: _selectedSystem,
                      activeColor: AppColors.teal,
                      // ignore: deprecated_member_use
                      onChanged: _isTesting
                          ? null
                          : (String? value) {
                              if (value != null) {
                                setState(() {
                                  _selectedSystem = value;
                                  _progress = 0.0;
                                });
                              }
                            },
                    );
                  }).toList(),
                ),
              ),

              const Spacer(),

              // Progress Bar
              if (_progress > 0.0) ...[
                Text(
                  _isTesting ? 'Running 5-second test...' : 'Test Finished',
                  style: TextStyle(
                    color: _isTesting ? AppColors.amber : AppColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: context.extras.border,
                  color: _isTesting ? AppColors.amber : AppColors.teal,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 32),
              ],

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTesting ? context.extras.border : AppColors.amber,
                    foregroundColor: _isTesting ? muted : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: _isTesting ? 0 : 2,
                  ),
                  onPressed: _isTesting ? null : _startTest,
                  child: Text(
                    _isTesting
                        ? 'TESTING IN PROGRESS...'
                        : 'START 5-SECOND TEST',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CARD & HELPER WIDGETS
// ==========================================

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.extras.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.extras.border),
      ),
      child: child,
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniAlertRow extends StatelessWidget {
  final Alert alert;
  const _MiniAlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.severityColor(alert.severity.name);
    final muted = context.extras.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(alert.title,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isConnected;
  final IconData icon;

  const _SensorTile({
    required this.title,
    required this.subtitle,
    required this.isConnected,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    final color = isConnected ? AppColors.teal : AppColors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isConnected ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// LIVE FIREBASE THERMAL MAP PREVIEW (UPDATED TO STATEFUL)
// ==========================================
class ThermalMapPreview extends StatefulWidget {
  final List<double> thermalData;

  const ThermalMapPreview({super.key, required this.thermalData});

  @override
  State<ThermalMapPreview> createState() => _ThermalMapPreviewState();
}

class _ThermalMapPreviewState extends State<ThermalMapPreview> {
  ui.Image? _thermalImage;

  @override
  void initState() {
    super.initState();
    _generateSmoothImage(widget.thermalData);
  }

  // This ensures the image re-renders when DashboardProvider pushes new thermalData
  @override
  void didUpdateWidget(ThermalMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thermalData != oldWidget.thermalData) {
      _generateSmoothImage(widget.thermalData);
    }
  }

  Future<void> _generateSmoothImage(List<double> data) async {
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

      // Color interpolation
      Color pixelColor;
      if (normalized < 0.5) {
        pixelColor = Color.lerp(Colors.blue, Colors.green, normalized * 2)!;
      } else {
        pixelColor = Color.lerp(Colors.green, Colors.red, (normalized - 0.5) * 2)!;
      }

      // Populate the RGBA array using the new float-based clamp math
      final int offset = i * 4;
      pixels[offset] = (pixelColor.r * 255.0).round().clamp(0, 255);
      pixels[offset + 1] = (pixelColor.g * 255.0).round().clamp(0, 255);
      pixels[offset + 2] = (pixelColor.b * 255.0).round().clamp(0, 255);
      pixels[offset + 3] = 255; // Alpha (fully opaque)
    }

    // Decode the raw bytes into a Flutter Image
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
  Widget build(BuildContext context) {
    if (widget.thermalData.isEmpty || _thermalImage == null) {
      return Container(
        height: 180,
        width: double.infinity,
        color: Colors.black12,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Connecting to thermal camera...'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: context.extras.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: SizedBox.expand(
        child: RawImage(
          image: _thermalImage,
          fit: BoxFit.fill,
          // Applies bilinear interpolation for smoothing
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}