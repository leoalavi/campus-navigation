import 'package:flutter/material.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_glass.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

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

    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
      padding: const EdgeInsets.all(4),
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
            horizontal: MqSpacing.space5,
            vertical: MqSpacing.space3,
          ),
          child: Text(
            label,
            style: TextStyle(
              // Unselected sat at white70 in dark mode, which dissolved into
              // the glass over a bright map. On-glass primary keeps the two
              // states distinct (red pill vs bare glass) while leaving the
              // inactive label properly readable rather than merely present.
              color: isSelected ? Colors.white : MqGlass.onGlassPrimary(isDark),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
