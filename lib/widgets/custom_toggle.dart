import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Row with a label on the left and a custom animated pill switch (44x24)
/// on the right. Thumb slides via an AnimationController.
class CustomToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const CustomToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  State<CustomToggle> createState() => _CustomToggleState();
}

class _CustomToggleState extends State<CustomToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant CustomToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        GestureDetector(
          onTap: _handleTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              final trackColor = Color.lerp(muted.withValues(alpha: 0.3),
                  AppColors.teal, t)!;
              return Container(
                width: 44,
                height: 24,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Align(
                  alignment: Alignment.lerp(
                    Alignment.centerLeft,
                    Alignment.centerRight,
                    t,
                  )!,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(muted, Colors.white, t),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
