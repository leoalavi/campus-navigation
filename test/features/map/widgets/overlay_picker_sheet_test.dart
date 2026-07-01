import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/map/presentation/widgets/overlay_picker_sheet.dart';

class _FakeMapController extends MapController {
  @override
  Future<MapState> build() async {
    return const MapState(buildings: <Building>[], searchResults: <Building>[]);
  }
}

Widget _app() {
  return ProviderScope(
    overrides: [mapControllerProvider.overrideWith(() => _FakeMapController())],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: OverlayPickerSheet()),
    ),
  );
}

void main() {
  testWidgets('renders a toggle row for every registered overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsWidgets);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(OverlayPickerSheet)),
    )!;
    expect(find.text(l10n.overlayParking), findsOneWidget);
  });

  testWidgets('does not show Clear All when no overlay is active', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OverlayPickerSheet)),
    )!;
    expect(find.text(l10n.clearAll), findsNothing);
  });

  testWidgets('toggling a switch activates it, then Clear All resets all', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OverlayPickerSheet)),
    )!;
    await tester.tap(find.text(l10n.overlayParking));
    await tester.pumpAndSettle();

    expect(find.text(l10n.clearAll), findsOneWidget);
    final switchWidget = tester.widget<Switch>(find.byType(Switch).first);
    expect(switchWidget.value, isTrue);

    await tester.tap(find.text(l10n.clearAll));
    await tester.pumpAndSettle();

    expect(find.text(l10n.clearAll), findsNothing);
    final resetSwitch = tester.widget<Switch>(find.byType(Switch).first);
    expect(resetSwitch.value, isFalse);
  });
}
