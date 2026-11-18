import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/features/map/presentation/widgets/google/desktop_map_fallback_view.dart';

/// Regression: in dark mode the OpenStreetMap fallback (macOS, web, and any
/// build without a Google Maps key) loaded CARTO's `dark_all` basemap, which
/// now requires an API key and serves an "API KEY REQUIRED" image instead of
/// a map. Both themes must use OSM tiles; dark mode darkens them client-side.
void main() {
  Future<TileLayer> pumpFallback(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DesktopMapFallbackView(
              searchResults: const [],
              searchQuery: '',
              selectedBuilding: null,
              route: null,
              currentLocation: null,
              locationCenterRequestToken: 0,
              isNavigating: false,
              onSelectBuilding: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<TileLayer>(find.byType(TileLayer));
  }

  for (final brightness in Brightness.values) {
    testWidgets('uses keyless OpenStreetMap tiles in ${brightness.name} mode', (
      tester,
    ) async {
      final layer = await pumpFallback(tester, brightness);

      expect(
        layer.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(layer.urlTemplate, isNot(contains('cartocdn')));
      expect(
        layer.tileBuilder != null,
        brightness == Brightness.dark,
        reason: 'only dark mode should darken the tiles',
      );
    });
  }
}
