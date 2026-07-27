import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/shared/widgets/campus_text.dart';

/// The exact strings the campus data ships, which mix Latin letters with
/// digits and punctuation — the combination that reorders under RTL.
const _addresses = <String>[
  "11 Wally's Walk",
  '14 Sir Christopher Ondaatje Avenue',
  '4 Research Park Drive',
  '4ER',
  '14SCO',
  '17WW',
  "Theatre G03, 1 Wally's Walk",
];

Widget _host(TextDirection direction, Widget child) => MaterialApp(
  home: Directionality(
    textDirection: direction,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('CampusText keeps Latin campus data in reading order', () {
    for (final direction in TextDirection.values) {
      testWidgets('$direction: lays the run out left-to-right', (tester) async {
        for (final address in _addresses) {
          await tester.pumpWidget(_host(direction, CampusText(address)));

          final text = tester.widget<Text>(find.text(address));
          // The run gets its own LTR paragraph, so "11" stays welded to
          // "Wally's Walk" instead of being flung to the far end of the line.
          expect(
            Directionality.of(tester.element(find.text(address))),
            TextDirection.ltr,
            reason: '$address must be laid out LTR in $direction',
          );
          // Never reordered by hand — the string is passed through intact.
          expect(text.data, address);
        }
      });
    }

    testWidgets('rtl: the block still sits on the reader side', (tester) async {
      await tester.pumpWidget(
        _host(TextDirection.rtl, const CampusText("11 Wally's Walk")),
      );
      final text = tester.widget<Text>(find.text("11 Wally's Walk"));
      expect(
        text.textAlign,
        TextAlign.right,
        reason: 'an RTL row reads from the right, even for Latin content',
      );
    });

    testWidgets('ltr: unchanged from a plain Text', (tester) async {
      await tester.pumpWidget(
        _host(TextDirection.ltr, const CampusText("11 Wally's Walk")),
      );
      final text = tester.widget<Text>(find.text("11 Wally's Walk"));
      expect(text.textAlign, TextAlign.left);
    });

    testWidgets('does not overflow a narrow phone row', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          TextDirection.rtl,
          const SizedBox(
            width: 140,
            child: CampusText(
              '14 Sir Christopher Ondaatje Avenue',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('DirectionalChevron', () {
    testWidgets('points along the reading direction', (tester) async {
      await tester.pumpWidget(
        _host(TextDirection.ltr, const DirectionalChevron()),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.pumpWidget(
        _host(TextDirection.rtl, const DirectionalChevron()),
      );
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });

  group('ltrIsolate', () {
    test('brackets the run in Unicode isolate marks, unmodified', () {
      // U+2066 LRI … U+2069 PDI — the run keeps its own direction and the
      // characters themselves are never reordered.
      expect(
        ltrIsolate('4ER'),
        '\u2066'
        '4ER'
        '\u2069',
      );
      expect(
        ltrIsolate('14SCO'),
        '\u2066'
        '14SCO'
        '\u2069',
      );
      expect(
        ltrIsolate("Theatre G03, 1 Wally's Walk"),
        '\u2066'
        "Theatre G03, 1 Wally's Walk"
        '\u2069',
      );
    });

    test('adds no visible characters', () {
      const code = '17WW';
      expect(ltrIsolate(code).replaceAll(RegExp(r'[\u2066\u2069]'), ''), code);
    });
  });
}
