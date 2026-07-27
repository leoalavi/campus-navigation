import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/shared/widgets/open_day_wordmark.dart';

/// The brand date chip is unlocalised Latin text, so in an RTL page its
/// leading "15" was reordered to the far end ("AUGUST 2026 · 10AM – 4PM 15").
void main() {
  const chipText = '15 AUGUST 2026  ·  10AM – 4PM';

  for (final direction in TextDirection.values) {
    testWidgets('$direction: the date keeps its written order', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: const Scaffold(body: Center(child: OpenDayDateChip())),
          ),
        ),
      );

      expect(find.text(chipText), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(chipText))),
        TextDirection.ltr,
        reason: 'the date must lay out LTR so "15" stays at the front',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
