import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/transit/domain/entities/transit_stop.dart';

void main() {
  group('TransitStop', () {
    test('parses stop search result JSON', () {
      final stop = TransitStop.fromJson({
        'id': '10101403',
        'name': 'Macquarie University Station',
      });

      expect(stop.id, '10101403');
      expect(stop.name, 'Macquarie University Station');
    });

    test('falls back to empty values for malformed JSON', () {
      final stop = TransitStop.fromJson(const {});

      expect(stop.id, isEmpty);
      expect(stop.name, isEmpty);
    });
  });
}
