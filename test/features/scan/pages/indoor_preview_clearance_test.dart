import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_tour_view.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scene_rail.dart';

void main() {
  testWidgets('scene rail clears the floating tab-bar island when embedded', (
    tester,
  ) async {
    // The island is `kTabBarIslandClearance` tall above the safe area; mirror
    // that as the stand-in bottom bar so the assertion is meaningful.
    const islandHeight = kTabBarIslandClearance;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          extendBody: true, // mirrors AppShell
          bottomNavigationBar: const SizedBox(height: islandHeight),
          body: IndoorTourView(
            manifest: const IndoorManifest(
              nodes: [IndoorNode(id: 'a', image: 'a.jpg', description: 'A')],
            ),
            reserveBottomForTabBar: true, // the in-shell indoorPreview case
            viewerBuilder:
                ({
                  required manifest,
                  required sceneId,
                  required onSceneChanged,
                }) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    final screenH = tester.getSize(find.byType(Scaffold)).height;
    final railBottom = tester.getBottomLeft(find.byType(SceneRail)).dy;
    // The rail's bottom must sit at or above the island's top edge.
    expect(railBottom, lessThanOrEqualTo(screenH - islandHeight + 1));
  });

  testWidgets('top-level route (no tab bar) leaves the rail at the bottom', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: IndoorTourView(
            manifest: const IndoorManifest(
              nodes: [IndoorNode(id: 'a', image: 'a.jpg', description: 'A')],
            ),
            // reserveBottomForTabBar defaults false (no tab bar to clear).
            viewerBuilder:
                ({
                  required manifest,
                  required sceneId,
                  required onSceneChanged,
                }) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    final screenH = tester.getSize(find.byType(Scaffold)).height;
    final railBottom = tester.getBottomLeft(find.byType(SceneRail)).dy;
    // No reservation → the rail's own box reaches the screen bottom.
    expect(railBottom, screenH);
  });
}
