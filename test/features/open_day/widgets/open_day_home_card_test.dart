import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/features/open_day/data/open_day_providers.dart';
import 'package:campus_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:campus_navigation/features/open_day/presentation/widgets/open_day_home_card.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:campus_navigation/shared/models/user_preferences.dart';

const _bachelor = OpenDayBachelor(
  id: 'comp-sci',
  name: 'Bachelor of Computer Science',
  studyAreaId: 'science',
);

final _event = OpenDayEvent(
  id: 'evt-1',
  title: 'COMP1010 Info Session',
  startTime: DateTime(2026, 8, 22, 10),
  endTime: DateTime(2026, 8, 22, 11),
  venueName: '1 Wally\'s Walk',
  bachelorIds: const ['comp-sci'],
);

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._prefs);
  final UserPreferences _prefs;

  @override
  Future<UserPreferences> build() async => _prefs;
}

Widget _app({
  required List<OpenDayEvent> events,
  String? selectedBachelorId,
  DateTime? now,
}) {
  return ProviderScope(
    overrides: [
      // Default to a week before the event; never the wall clock, which
      // drifts past the fixture date and flips the card to "finished".
      openDayNowProvider.overrideWithValue(now ?? DateTime(2026, 8, 15, 9)),
      settingsControllerProvider.overrideWith(
        () => _FakeSettingsController(
          UserPreferences(selectedBachelorId: selectedBachelorId),
        ),
      ),
      selectedBachelorProvider.overrideWithValue(
        selectedBachelorId == null ? null : _bachelor,
      ),
      openDayDataProvider.overrideWith(
        (ref) async => OpenDayData(
          openDayDate: DateTime(2026, 8, 22),
          lastUpdated: DateTime.now(),
          studyAreas: const [],
          bachelors: const [_bachelor],
          events: events,
        ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: OpenDayHomeCard()),
    ),
  );
}

void main() {
  setUpAll(() => tz.initializeTimeZones());

  testWidgets('shows the onboarding CTA when no bachelor is selected', (
    tester,
  ) async {
    await tester.pumpWidget(_app(events: const []));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OpenDayHomeCard)),
    )!;
    expect(find.text(l10n.openDay_interestedInStudying), findsOneWidget);
  });

  testWidgets('shows the selected bachelor and its upcoming session', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(events: [_event], selectedBachelorId: 'comp-sci'),
    );
    await tester.pumpAndSettle();

    expect(find.text(_bachelor.name), findsOneWidget);
    expect(find.textContaining(_event.venueName), findsOneWidget);
  });

  testWidgets('preview skips sessions that already ended on the day', (
    tester,
  ) async {
    final morning = OpenDayEvent(
      id: 'evt-am',
      title: 'Morning Tour',
      startTime: DateTime(2026, 8, 22, 9),
      endTime: DateTime(2026, 8, 22, 10),
      venueName: 'Morning Venue',
      bachelorIds: const ['comp-sci'],
    );
    final afternoon = OpenDayEvent(
      id: 'evt-pm',
      title: 'Afternoon Talk',
      startTime: DateTime(2026, 8, 22, 15),
      endTime: DateTime(2026, 8, 22, 16),
      venueName: 'Afternoon Venue',
      bachelorIds: const ['comp-sci'],
    );
    await tester.pumpWidget(
      _app(
        events: [morning, afternoon],
        selectedBachelorId: 'comp-sci',
        now: DateTime(2026, 8, 22, 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Afternoon Venue'), findsOneWidget);
    expect(find.textContaining('Morning Venue'), findsNothing);
  });

  testWidgets('says the Open Day has finished once every session ended', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        events: [_event],
        selectedBachelorId: 'comp-sci',
        now: DateTime(2026, 8, 22, 20),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OpenDayHomeCard)),
    )!;
    expect(find.text(l10n.openDay_finishedTitle), findsOneWidget);
    // Last event's sessions are no longer presented as upcoming.
    expect(find.textContaining(_event.venueName), findsNothing);
  });

  testWidgets(
    'shows the empty-sessions copy when the selected degree has none',
    (tester) async {
      // A published program with nothing for this degree.
      final otherDegree = OpenDayEvent(
        id: 'evt-other',
        title: 'Business Info Session',
        startTime: DateTime(2026, 8, 22, 10),
        endTime: DateTime(2026, 8, 22, 11),
        venueName: 'Other Venue',
        bachelorIds: const ['business'],
      );
      await tester.pumpWidget(
        _app(events: [otherDegree], selectedBachelorId: 'comp-sci'),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(OpenDayHomeCard)),
      )!;
      expect(find.text(l10n.openDay_noSessionsYet), findsOneWidget);
    },
  );

  testWidgets('says the program is not published yet when there are no '
      'sessions at all (date announced, program pending)', (tester) async {
    await tester.pumpWidget(
      _app(events: const [], selectedBachelorId: 'comp-sci'),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OpenDayHomeCard)),
    )!;
    expect(find.text(l10n.openDay_programPending), findsOneWidget);
    expect(find.text(l10n.openDay_noSessionsYet), findsNothing);
    expect(find.text(l10n.openDay_finishedTitle), findsNothing);
  });
}
