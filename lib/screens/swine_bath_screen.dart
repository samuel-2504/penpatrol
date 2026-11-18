import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_provider.dart';
import '../models/schedule.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/title_bar.dart';
import '../widgets/custom_slider.dart';

String _formatDuration(double minutes) {
  final totalSeconds = (minutes * 60).round();
  final minuteText = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final secondText = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minuteText:$secondText';
}

class SwineBathScreen extends StatelessWidget {
  const SwineBathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final pad = Responsive.pagePadding(context);
    final muted = context.extras.muted;

    return Scaffold(
      appBar: const TitleBar(
        screenName: 'Swine Bath',
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.teal,
        onPressed: () => _showAddScheduleSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ResponsiveScaffoldBody(
        child: RefreshIndicator(
          onRefresh: provider.fetchSchedules,
          color: AppColors.teal,
          child: provider.isLoading && provider.schedules.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                )
              : provider.schedules.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 40, color: muted),
                              const SizedBox(height: 12),
                              Text('No active swine bath schedules',
                                  style: TextStyle(color: muted)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(pad, pad, pad, 80),
                      itemCount: provider.schedules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final s = provider.schedules[i];
                        return _ScheduleCard(schedule: s);
                      },
                    ),
        ),
      ),
    );
  }

  void _showAddScheduleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddScheduleForm(),
    );
  }
}

// --- SCHEDULE CARD WIDGET ---
class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScheduleProvider>();
    final muted = context.extras.muted;
    final border = context.extras.border;

    // Calculate dynamic servo degrees for display
    final int servoAngle = ((schedule.intensity / 100.0) * 90.0).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.extras.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.water_drop_rounded, color: AppColors.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  '${schedule.time} · ${schedule.selectedDays.join(", ")}',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Valve: $servoAngle° (${schedule.intensity.toStringAsFixed(0)}%) · Pump: ${_formatDuration(schedule.duration)}',
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Switch(
            value: schedule.enabled,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.teal,
            onChanged: (v) => provider.toggleEnabled(schedule.id, v),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: muted),
            onPressed: () => provider.removeSchedule(schedule.id),
          ),
        ],
      ),
    );
  }
}

// --- FORM BOTTOM SHEET ---
class _AddScheduleForm extends StatefulWidget {
  const _AddScheduleForm();

  @override
  State<_AddScheduleForm> createState() => _AddScheduleFormState();
}

class _AddScheduleFormState extends State<_AddScheduleForm> {
  final _titleController = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final List<String> _selectedDays = [];
  double _intensity = 70.0;
  double _duration = 15.0;
  bool _isSaving = false;

  String? _errorMessage;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() {
      _errorMessage = null;
    });

    if (_titleController.text.trim().isEmpty || _selectedDays.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a title and select at least one day.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final schedule = Schedule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        time:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        selectedDays: List.from(_selectedDays),
        intensity: _intensity,
        duration: _duration,
        enabled: true, // Auto-enable newly added schedule
      );

      await context.read<ScheduleProvider>().addSchedule(schedule);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save to Firebase. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    final border = context.extras.border;
    final int calculatedAngle = ((_intensity / 100.0) * 90.0).round();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Swine Bath Schedule',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Schedule Title (e.g. Midday Cooling)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time', style: TextStyle(color: muted)),
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_time.format(context)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Repeat on', style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _days.map((d) {
                final selected = _selectedDays.contains(d);
                return FilterChip(
                  label: Text(d),
                  selected: selected,
                  selectedColor: AppColors.teal.withValues(alpha: 0.25),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedDays.add(d);
                      } else {
                        _selectedDays.remove(d);
                      }
                      if (_errorMessage != null) {
                        _errorMessage = null;
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.extras.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Water Pump & Servo Settings',
                          style: TextStyle(
                              color: muted, fontWeight: FontWeight.bold)),
                      Text('$calculatedAngle° Servo',
                          style: const TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomSlider(
                    label: 'Valve Intensity (5% steps)',
                    value: _intensity,
                    min: 0,
                    max: 100,
                    unit: '%',
                    divisions: 20,
                    onChanged: (val) => setState(() => _intensity = val),
                  ),
                  const SizedBox(height: 12),
                  CustomSlider(
                    label: 'Pump Relay Duration (MM:SS, 30s steps)',
                    value: _duration,
                    min: 0.5,
                    max: 30,
                    unit: '',
                    divisions: 59,
                    valueFormatter: _formatDuration,
                    onChanged: (val) => setState(() => _duration = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Schedule',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}