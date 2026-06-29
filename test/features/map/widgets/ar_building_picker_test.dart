import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/presentation/widgets/ar_building_picker.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/scan/data/repositories/trail_repository.dart';
import 'package:mq_journey/features/scan/data/repositories/indoor_repository.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';

class _MultiFakeTrailRepository extends TrailRepository {
  @override
  Future<TrailManifest> load() async => TrailManifest(
    locations: [
      TrailLocation(locationId: 'lib-01', buildingId: 'C3A', title: 'Library'),
      TrailLocation(
        locationId: 'sc-01',
        buildingId: 'E7A',
        title: 'Engineering',
      ),
      TrailLocation(
        locationId: 'sc-02',
        buildingId: '18WW',
        title: 'Service Connect',
      ),
    ],
  );
}

class _SingleFakeTrailRepository extends TrailRepository {
  @override
  Future<TrailManifest> load() async => TrailManifest(
    locations: [
      TrailLocation(locationId: 'lib-01', buildingId: 'C3A', title: 'Library'),
      TrailLocation(
        locationId: 'sc-02',
        buildingId: '18WW',
        title: 'Service Connect',
      ),
    ],
  );
}

class _FakeIndoorRepository extends IndoorRepository {
  @override
  Future<IndoorManifest?> load(String buildingId) async {
    if (buildingId.toLowerCase() == 'c3a') {
      return IndoorManifest(
        nodes: [
          IndoorNode(id: 'lobby', image: 'c3a/lobby.jpg', description: 'Lobby'),
        ],
      );
    }
    if (buildingId.toLowerCase() == 'e7a') {
      return IndoorManifest(
        nodes: [
          IndoorNode(
            id: 'entrance',
            image: 'e7a/entrance.jpg',
            description: 'Entrance',
          ),
        ],
      );
    }
    return null;
  }
}

Widget _buildApp({
  required TrailRepository trailRepo,
  required IndoorRepository indoorRepo,
  required void Function(String) onSelect,
}) {
  return ProviderScope(
    overrides: [
      trailRepositoryProvider.overrideWith((_) => trailRepo),
      indoorRepositoryProvider.overrideWith((_) => indoorRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ArBuildingPicker(onSelect: onSelect)),
    ),
  );
}

void main() {
  testWidgets('renders manifest and non-manifest buildings', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        trailRepo: _MultiFakeTrailRepository(),
        indoorRepo: _FakeIndoorRepository(),
        onSelect: (_) {},
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // C3A has a manifest, 18WW does not, E7A has a manifest
    expect(find.text('C3A'), findsOneWidget);
    expect(find.text('E7A'), findsOneWidget);
    expect(find.text('18WW'), findsOneWidget);
  });

  testWidgets('auto-selects when exactly one building has manifest', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _buildApp(
        trailRepo: _SingleFakeTrailRepository(),
        indoorRepo: _FakeIndoorRepository(),
        onSelect: (id) => selected = id,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(selected, 'C3A');
  });
}
