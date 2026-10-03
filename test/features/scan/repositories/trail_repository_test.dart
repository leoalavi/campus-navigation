import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/features/scan/data/repositories/trail_repository.dart';
import 'package:mq_navigation/features/scan/domain/models/trail_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrailRepository', () {
    test('loads and caches manifest', () async {
      final repo = TrailRepository();
      final manifest = await repo.load();
      expect(manifest, isA<TrailManifest>());
      final cached = await repo.load();
      expect(
        identical(manifest, cached),
        isTrue,
        reason: 'second load should return cached instance',
      );
    });
  });
}
