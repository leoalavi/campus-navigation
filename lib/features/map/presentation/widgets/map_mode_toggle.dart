import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';

enum MapMode { campusMap, ar }

class MapModeToggle extends StatelessWidget {
  const MapModeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.campusMapLabel,
    this.arLabel,
  });

  final MapMode value;
  final ValueChanged<MapMode> onChanged;
  final String? campusMapLabel;
  final String? arLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const segments = MapMode.values;

    return ClipRRect(
      borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? MqColors.charcoal800.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : MqColors.charcoal800.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in segments) ...[
                if (mode != segments.first) const SizedBox(width: 2),
                _SegmentButton(
                  label: mode == MapMode.campusMap
                      ? (campusMapLabel ?? 'Campus Map')
                      : (arLabel ?? 'AR'),
                  isSelected: value == mode,
                  isDark: isDark,
                  onTap: () => onChanged(mode),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? MqColors.red : Colors.transparent,
      borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.space4,
            vertical: MqSpacing.space2,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : MqColors.charcoal800),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
