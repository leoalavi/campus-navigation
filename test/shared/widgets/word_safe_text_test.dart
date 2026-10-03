import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/shared/widgets/word_safe_text.dart';

/// Regression: Quick Access tile labels broke mid-word ("Student Service / s")
/// on small phones with large text.
void main() {
  Future<RenderWordSafeText> pumpAt(
    WidgetTester tester,
    double width, {
    bool intrinsic = false,
  }) async {
    Widget text = const WordSafeText(
      'Student Services',
      style: TextStyle(fontSize: 24),
    );
    if (intrinsic) {
      text = IntrinsicHeight(
        child: Row(children: [Expanded(child: text)]),
      );
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(width: width, child: text),
        ),
      ),
    );
    return tester.renderObject<RenderWordSafeText>(find.byType(WordSafeText));
  }

  testWidgets('keeps the requested size when every word fits', (tester) async {
    final r = await pumpAt(tester, 400);
    expect(r.appliedFactor, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shrinks rather than splitting a word that cannot fit', (
    tester,
  ) async {
    final r = await pumpAt(tester, 80);
    expect(r.appliedFactor, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('works inside IntrinsicHeight (the Quick Access tiles)', (
    tester,
  ) async {
    final r = await pumpAt(tester, 80, intrinsic: true);
    expect(r.appliedFactor, lessThan(1));
    expect(r.size.height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes its text to accessibility', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 400);
    expect(find.bySemanticsLabel('Student Services'), findsOneWidget);
    handle.dispose();
  });
}
