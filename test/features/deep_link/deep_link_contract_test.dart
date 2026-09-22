import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/deep_link/deep_link_contract.dart';

void main() {
  group('MqNavDeepLink.isOpenLink', () {
    test('accepts the custom scheme', () {
      expect(
        MqNavDeepLink.isOpenLink(Uri.parse('mqnav://open?destination=17WW')),
        isTrue,
      );
    });

    test('accepts the verified https link', () {
      expect(
        MqNavDeepLink.isOpenLink(
          Uri.parse('https://mqnavigation.app/open?q=library'),
        ),
        isTrue,
      );
    });

    // Regression guard: the Supabase auth callback shares a scheme prefix with
    // the app. Treating it as a navigation link would hijack sign-in.
    test('rejects auth callbacks and unrelated links', () {
      for (final u in const [
        'io.mqnavigation://callback?code=abc',
        'https://mqnavigation.io/auth/confirm',
        'https://example.com/open?destination=17WW',
        'https://mqnavigation.app/other',
        'mqnav://somethingelse',
      ]) {
        expect(MqNavDeepLink.isOpenLink(Uri.parse(u)), isFalse, reason: u);
      }
    });
  });

  group('parseMqNavDeepLink', () {
    test('destination wins over query and coordinates', () {
      final t = parseMqNavDeepLink({
        'destination': '17WW',
        'q': 'x',
        'lat': '1',
        'lng': '2',
      });
      expect((t as DeepLinkBuilding).buildingId, '17WW');
    });

    test('falls through to search, then coordinates', () {
      expect(parseMqNavDeepLink({'q': 'library'}), isA<DeepLinkSearch>());
      expect(
        parseMqNavDeepLink({'lat': '-33.77', 'lng': '151.11'}),
        isA<DeepLinkMeetAt>(),
      );
    });

    test('missing, blank and unparseable payloads fall back', () {
      for (final p in const [
        <String, String>{},
        {'destination': '   '},
        {'q': ''},
        {'lat': 'abc', 'lng': 'def'},
        {'lat': '-33.77'}, // half a coordinate pair
      ]) {
        expect(parseMqNavDeepLink(p), isA<DeepLinkFallback>(), reason: '$p');
      }
    });
  });

  group('buildCampusNavBuildingLink', () {
    test('round-trips through the parser', () {
      for (final https in const [true, false]) {
        final uri = buildCampusNavBuildingLink('14SCO', https: https);
        expect(MqNavDeepLink.isOpenLink(uri), isTrue, reason: '$uri');
        final t = parseMqNavDeepLink(uri.queryParameters);
        expect((t as DeepLinkBuilding).buildingId, '14SCO');
      }
    });

    test('escapes ids that would otherwise break the query string', () {
      final uri = buildCampusNavBuildingLink('A&B C');
      expect(parseMqNavDeepLink(uri.queryParameters), isA<DeepLinkBuilding>());
      expect(
        (parseMqNavDeepLink(uri.queryParameters) as DeepLinkBuilding)
            .buildingId,
        'A&B C',
      );
    });
  });
}
