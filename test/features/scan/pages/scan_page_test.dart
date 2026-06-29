import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/presentation/pages/scan_page.dart';

Widget _buildTestApp() {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ScanPage(),
    ),
  );
}

void main() {
  testWidgets('renders scan page with app bar', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    expect(find.byType(ScanPage), findsOneWidget);
  });

  testWidgets('shows torch toggle in scanning state', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    expect(find.byIcon(Icons.flash_off), findsOneWidget);
  });

  testWidgets('lifecycle disposes controller cleanly', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(find.byType(ScanPage), findsNothing);
  });
}
