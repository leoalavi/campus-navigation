import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/features/open_day/data/open_day_providers.dart';
import 'package:campus_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:campus_navigation/features/open_day/presentation/pages/open_day_page.dart';

/// The next Open Day (14 Aug 2027) is announced before its session program.
/// The page must say the program isn't published — not that a filter found
/// nothing, and never show last year's sessions.
void main() {
  setUpAll(tz.initializeTimeZones);

  Widget app(List<OpenDayEvent> events) => ProviderScope(
    overrides: [
      selectedBachelorProvider.overrideWithValue(null),
      openDayDataProvider.overrideWith(
        (ref) async => OpenDayData(
          openDayDate: DateTime(2027, 8, 14),
          lastUpdated: DateTime(2026, 10, 3),
          studyAreas: const [],
          bachelors: const [],
          events: events,
        ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OpenDayPage(),
    ),
  );

  testWidgets('program not yet published', (tester) async {
    await tester.pumpWidget(app(const []));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(OpenDayPage)))!;

    expect(find.text(l10n.openDay_programPending), findsOneWidget);
    expect(find.text(l10n.openDay_noEventsNoneSelected), findsNothing);
    // The announced date is still shown.
    expect(find.textContaining('SATURDAY 14 AUGUST 2027'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
