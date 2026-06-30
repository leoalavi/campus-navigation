import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/presentation/pages/location_ar_page.dart';

void main() {
  final manifest = IndoorManifest.fromJson(
    '{"nodes":[{"id":"entrance","image":"a.jpg","neighbours":[]},'
    '{"id":"theatre-g03","image":"b.jpg","neighbours":[]}]}',
  );

  test('resolves a valid stop scene', () {
    expect(
      resolveArFirstScene(
        manifest: manifest,
        stopSceneId: 'theatre-g03',
        entranceSceneId: 'entrance',
      ),
      'theatre-g03',
    );
  });

  test('falls back to entrance when stop scene missing', () {
    expect(
      resolveArFirstScene(
        manifest: manifest,
        stopSceneId: 'nope',
        entranceSceneId: 'entrance',
      ),
      'entrance',
    );
  });

  test('returns null when neither resolves', () {
    expect(
      resolveArFirstScene(
        manifest: manifest,
        stopSceneId: 'nope',
        entranceSceneId: 'also-nope',
      ),
      isNull,
    );
  });
}
