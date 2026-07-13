import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/widgets/indoor_stop_list.dart';

const _manifest = IndoorManifest(
  nodes: [
    IndoorNode(
      id: 'entrance',
      image: 'indoor/entrance.jpg',
      description: "Entrance — 1 Wally's Walk",
    ),
    IndoorNode(id: 'g03', image: 'indoor/g03.jpg', description: 'Theatre G03'),
  ],
);

Widget _app({required String selected, ValueChanged<String>? onSelected}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: IndoorStopList(
        manifest: _manifest,
        selectedSceneId: selected,
        onSceneSelected: onSelected,
      ),
    ),
  );
}

void main() {
  testWidgets('tapping a scene row requests that exact scene', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _app(selected: 'entrance', onSelected: (value) => selected = value),
    );

    await tester.tap(find.text('Theatre G03'));

    expect(selected, 'g03');
  });

  testWidgets('current scene row is visually selected', (tester) async {
    await tester.pumpWidget(_app(selected: 'g03', onSelected: (_) {}));

    final entrance = tester.widget<ListTile>(
      find.ancestor(
        of: find.text("Entrance — 1 Wally's Walk"),
        matching: find.byType(ListTile),
      ),
    );
    final g03 = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Theatre G03'),
        matching: find.byType(ListTile),
      ),
    );

    expect(entrance.selected, isFalse);
    expect(g03.selected, isTrue);
    expect(g03.onTap, isNotNull);
  });
}
