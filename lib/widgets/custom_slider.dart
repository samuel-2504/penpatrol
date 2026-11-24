import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Row 1: label (left) + value+unit in yellow mono (right).
/// Row 2: Slider with teal fill / muted remainder track.
class CustomSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final String Function(double value)? valueFormatter;

  const CustomSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.divisions,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueFormatter?.call(value) ?? '${value.toStringAsFixed(0)}$unit',
              style: const TextStyle(
                color: AppColors.yellow,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.teal,
            inactiveTrackColor: muted.withValues(alpha: 0.25),
            thumbColor: AppColors.teal,
            overlayColor: AppColors.teal.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
