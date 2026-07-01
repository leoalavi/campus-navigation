import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';

const _award = StampAward(
  stamp: StampCatalogEntry(
    locationId: 'wallys-1',
    title: "1 Wally's Walk",
    mapRef: 'K27',
    stampAsset: 'assets/stamps/wallys-1.png',
  ),
  collectedCount: 1,
  total: 9,
  isFirst: true,
  isComplete: false,
);

Widget _app(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('shows the stamp title, first-visit note, and progress', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showStampEarnedSheet(context, _award),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StampEarnedSheet)),
    )!;
    expect(find.text(l10n.stampCelebrationTitle), findsOneWidget);
    expect(
      find.text(l10n.stampCelebrationSubtitle(_award.stamp.title)),
      findsOneWidget,
    );
    expect(find.text(l10n.stampCelebrationFirstNote), findsOneWidget);
    expect(find.text('1/9'), findsOneWidget);
  });

  testWidgets('View my passport CTA returns StampSheetAction.viewPassport', (tester) async {
    StampSheetAction? result;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStampEarnedSheet(context, _award);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StampEarnedSheet)),
    )!;
    await tester.tap(find.text(l10n.stampCelebrationViewPassport));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, StampSheetAction.viewPassport);
  });

  testWidgets('reduce-motion skips confetti but still renders content', (tester) async {
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showStampEarnedSheet(context, _award),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(StampEarnedSheet), findsOneWidget);
  });
}
