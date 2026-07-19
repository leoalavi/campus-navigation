import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_tour_view.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scene_rail.dart';

IndoorManifest _m() => const IndoorManifest(
  nodes: [
    IndoorNode(id: 'lobby', image: 'a.jpg', description: 'Lobby'),
    IndoorNode(id: 't1', image: 'b.jpg', description: 'Theatre 1'),
  ],
);

// Fake viewer: records the scene it was asked to show; can push a scene change.
class _FakeViewer extends StatelessWidget {
  const _FakeViewer({required this.sceneId, required this.onSceneChanged});
  final String sceneId;
  final ValueChanged<String> onSceneChanged;
  @override
  Widget build(BuildContext context) => Center(child: Text('viewer:$sceneId'));
}

Widget _host({String? firstSceneId}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: IndoorTourView(
      manifest: _m(),
      firstSceneId: firstSceneId,
      viewerBuilder:
          ({required manifest, required sceneId, required onSceneChanged}) =>
              _FakeViewer(sceneId: sceneId, onSceneChanged: onSceneChanged),
    ),
  ),
);

void main() {
  testWidgets('full-bleed viewer + floating rail, no Column/Divider split', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.byType(SceneRail), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
    expect(find.text('viewer:lobby'), findsOneWidget); // opens first scene
  });

  testWidgets('rail chip tap drives the viewer scene', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('Theatre 1'));
    await tester.pump();
    expect(find.text('viewer:t1'), findsOneWidget);
    expect(
      tester.widget<SceneRail>(find.byType(SceneRail)).selectedSceneId,
      't1',
    );
  });

  testWidgets('invalid firstSceneId falls back to the first node', (
    tester,
  ) async {
    await tester.pumpWidget(_host(firstSceneId: 'nope'));
    expect(find.text('viewer:lobby'), findsOneWidget);
  });
}
