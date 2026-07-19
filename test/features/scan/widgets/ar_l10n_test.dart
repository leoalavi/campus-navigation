import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';

void main() {
  test('AR keys resolve to English copy', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(l10n.arExploreTitle, 'Explore in 360°');
    expect(l10n.arExploreEyebrow, '360° campus tours');
    expect(
      l10n.arExploreSubtitle,
      'Step inside campus spaces before you arrive.',
    );
    expect(l10n.arTourComingSoon, 'Tour coming soon');
    expect(l10n.arSoonPill, 'Soon');
    expect(l10n.indoorScenesLabel, 'Scenes');
    expect(l10n.arSceneCount(1), '1 scene · 360° tour');
    expect(l10n.arSceneCount(6), '6 scenes · 360° tour');
  });
}
