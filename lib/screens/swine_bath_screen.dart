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

enum _ValveLevel {
  low('Low', 35),
  normal('Normal', 55),
  high('High', 75);

  const _ValveLevel(this.label, this.angle);

  final String label;
  final int angle;

  double get intensity => angle / 90.0 * 100.0;

  static _ValveLevel nearestToIntensity(double intensity) {
    final angle = intensity / 100.0 * 90.0;
    return values.reduce(
      (closest, level) =>
          (level.angle - angle).abs() < (closest.angle - angle).abs()
              ? level
              : closest,
    );
  }
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
        onPressed: () => _showScheduleSheet(context),
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
                        return _ScheduleCard(
                          schedule: s,
                          onEdit: () => _showScheduleSheet(context, s),
                        );
                      },
                    ),
        ),
      ),
    );
  }

  void _showScheduleSheet(BuildContext context, [Schedule? schedule]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScheduleForm(schedule: schedule),
    );
  }
}

// --- SCHEDULE CARD WIDGET ---
class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onEdit;

  const _ScheduleCard({required this.schedule, required this.onEdit});

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
                        fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${schedule.time} · ${schedule.selectedDays.join(", ")}',
                  style: TextStyle(color: muted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Valve: $servoAngle° · Pump: ${_formatDuration(schedule.duration)}',
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
            icon: Icon(Icons.edit_outlined, color: muted),
            tooltip: 'Edit schedule',
            onPressed: onEdit,
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
class _ScheduleForm extends StatefulWidget {
  final Schedule? schedule;

  const _ScheduleForm({this.schedule});

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final _titleController = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final List<String> _selectedDays = [];
  _ValveLevel _valveLevel = _ValveLevel.normal;
  double _duration = 5.0;
  bool _isSaving = false;

  String? _errorMessage;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    if (schedule != null) {
      _titleController.text = schedule.title;
      final timeParts = schedule.time.split(':');
      if (timeParts.length == 2) {
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (hour != null &&
            minute != null &&
            hour >= 0 &&
            hour < 24 &&
            minute >= 0 &&
            minute < 60) {
          _time = TimeOfDay(hour: hour, minute: minute);
        }
      }
      _selectedDays.addAll(schedule.selectedDays);
      _valveLevel = _ValveLevel.nearestToIntensity(schedule.intensity);
      _duration = schedule.duration
          .clamp(Schedule.minDurationMinutes, Schedule.maxDurationMinutes)
          .toDouble();
    }
  }

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
      final existingSchedule = widget.schedule;
      final schedule = Schedule(
        id: existingSchedule?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        time:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        selectedDays: List.from(_selectedDays),
        intensity: _valveLevel.intensity,
        duration: _duration,
        enabled: existingSchedule?.enabled ?? true,
      );

      final provider = context.read<ScheduleProvider>();
      if (existingSchedule == null) {
        await provider.addSchedule(schedule);
      } else {
        await provider.updateSchedule(schedule);
      }

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
            Text(
                widget.schedule == null
                    ? 'New Swine Bath Schedule'
                    : 'Edit Swine Bath Schedule',
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
                      Expanded(
                        child: Text(
                          'Water Pump & Servo Settings',
                          style: TextStyle(
                              color: muted, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${_valveLevel.angle}° Servo',
                          style: const TextStyle(
                              color: AppColors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: _ValveLevel.values.map((level) {
                      return ChoiceChip(
                        label: Text('${level.label} (${level.angle}°)'),
                        selected: _valveLevel == level,
                        selectedColor: AppColors.teal.withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => _valveLevel = level),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  CustomSlider(
                    label: 'Pump Relay Duration (1–10 min, 30s steps)',
                    value: _duration,
                    min: Schedule.minDurationMinutes,
                    max: Schedule.maxDurationMinutes,
                    unit: '',
                    divisions: 18,
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
                    : Text(
                        widget.schedule == null
                            ? 'Save Schedule'
                            : 'Update Schedule',
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
