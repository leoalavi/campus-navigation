import 'package:flutter/material.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';

class StampProgressRing extends StatelessWidget {
  const StampProgressRing({
    super.key,
    required this.collected,
    required this.total,
    this.size = 64,
  });

  final int collected;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (collected / total).clamp(0.0, 1.0);
    // Track flips to a light ink in dark mode; a fixed charcoal track is
    // invisible on the dark scaffold.
    final track = (context.isDarkMode ? Colors.white : MqColors.charcoal800)
        .withValues(alpha: context.isDarkMode ? 0.16 : 0.08);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: track,
              valueColor: const AlwaysStoppedAnimation<Color>(MqColors.red),
            ),
          ),
          Text(
            '$collected/$total',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
