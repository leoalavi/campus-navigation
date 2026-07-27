import 'package:flutter/material.dart';
import 'package:mq_journey/shared/widgets/campus_text.dart';

/// The "(OPEN DAY)us" campaign wordmark, rendered in type rather than as a
/// bitmap so it stays crisp at any size and can be tinted per surface.
///
/// This is a brand mark (like a logo), so it is intentionally NOT localised —
/// it must render identically in every locale, matching the official
/// Open Day 2026 material.
class OpenDayWordmark extends StatelessWidget {
  const OpenDayWordmark({
    super.key,
    this.color = Colors.white,
    this.fontSize = 34,
  });

  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final parenStyle = TextStyle(
      color: color.withValues(alpha: 0.55),
      fontSize: fontSize * 1.12,
      fontWeight: FontWeight.w300,
      height: 1.0,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '(', style: parenStyle),
          TextSpan(
            text: 'OPEN DAY',
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: fontSize * 0.02,
              height: 1.0,
            ),
          ),
          TextSpan(text: ')', style: parenStyle),
          TextSpan(
            text: 'us',
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: fontSize * 0.52,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              height: 0.6,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: 'Open Day',
    );
  }
}

/// Small "15 AUGUST 2026 · 10AM – 4PM" event chip that accompanies the
/// wordmark. Event dates on brand material are also left unlocalised.
class OpenDayDateChip extends StatelessWidget {
  const OpenDayDateChip({
    super.key,
    this.foreground = Colors.white,
    this.background = Colors.white24,
  });

  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        // Latin-script brand data in a possibly-RTL page: without its own
        // LTR paragraph the leading "15" was pushed to the far end of the
        // line in Persian ("AUGUST 2026 · 10AM – 4PM 15").
        child: CampusText(
          '15 AUGUST 2026  ·  10AM – 4PM',
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
