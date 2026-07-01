import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/open_day/presentation/widgets/open_day_home_card.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

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

Widget _app({required List<OpenDayEvent> events, String? selectedBachelorId}) {
  return ProviderScope(
    overrides: [
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
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: OpenDayHomeCard()),
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

  testWidgets(
    'shows the empty-sessions copy when the selected degree has none',
    (tester) async {
      await tester.pumpWidget(
        _app(events: const [], selectedBachelorId: 'comp-sci'),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(OpenDayHomeCard)),
      )!;
      expect(find.text(l10n.openDay_noSessionsYet), findsOneWidget);
    },
  );
}
