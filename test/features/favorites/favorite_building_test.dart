import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';

void main() {
  final now = DateTime.now();

  final fullJson = {
    'id': 'fav-1',
    'user_id': 'user-1',
    'building_id': 'BLD',
    'building_name': 'Library',
    'note': 'my favourite spot',
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  };

  final expected = FavoriteBuilding(
    id: 'fav-1',
    userId: 'user-1',
    buildingId: 'BLD',
    buildingName: 'Library',
    note: 'my favourite spot',
    createdAt: now,
    updatedAt: now,
  );

  group('fromJson', () {
    test('parses all fields', () {
      final result = FavoriteBuilding.fromJson(fullJson);
      expect(result.id, 'fav-1');
      expect(result.userId, 'user-1');
      expect(result.buildingId, 'BLD');
      expect(result.buildingName, 'Library');
      expect(result.note, 'my favourite spot');
      expect(result.createdAt, now);
      expect(result.updatedAt, now);
    });

    test('handles null note', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('note');
      final result = FavoriteBuilding.fromJson(json);
      expect(result.note, isNull);
    });
  });

  group('toJson', () {
    test('produces correct map', () {
      final json = expected.toJson();
      expect(json['id'], 'fav-1');
      expect(json['user_id'], 'user-1');
      expect(json['building_id'], 'BLD');
      expect(json['building_name'], 'Library');
      expect(json['note'], 'my favourite spot');
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());
    });

    test('round-trips through fromJson', () {
      final json = expected.toJson();
      final roundTrip = FavoriteBuilding.fromJson(json);
      expect(roundTrip, expected);
    });
  });

  group('copyWith', () {
    test('updates specified fields', () {
      final modified = expected.copyWith(note: 'new note');
      expect(modified.id, 'fav-1');
      expect(modified.note, 'new note');
    });

    test('clears note when clearNote is true', () {
      final modified = expected.copyWith(clearNote: true);
      expect(modified.note, isNull);
    });

    test('preserves unspecified fields', () {
      final modified = expected.copyWith(note: 'updated');
      expect(modified.buildingId, 'BLD');
      expect(modified.buildingName, 'Library');
    });
  });

  group('equality', () {
    test('equal when ids match', () {
      final a = FavoriteBuilding(
        id: 'same-id',
        userId: 'u1',
        buildingId: 'BLD',
        buildingName: 'A',
        createdAt: now,
        updatedAt: now,
      );
      final b = FavoriteBuilding(
        id: 'same-id',
        userId: 'u2',
        buildingId: 'BLD2',
        buildingName: 'B',
        createdAt: now,
        updatedAt: now,
      );
      expect(a, b);
    });

    test('not equal when ids differ', () {
      final a = expected;
      final b = expected.copyWith(id: 'different');
      expect(a, isNot(b));
    });
  });

  group('hashCode', () {
    test('matches id hash', () {
      expect(expected.hashCode, 'fav-1'.hashCode);
    });
  });

  group('toString', () {
    test('contains building id and name', () {
      final str = expected.toString();
      expect(str, contains('BLD'));
      expect(str, contains('Library'));
    });
  });
}
