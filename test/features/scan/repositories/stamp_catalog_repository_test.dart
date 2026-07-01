import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/data/repositories/stamp_catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads all 9 canonical stamp catalogue entries from the bundled asset', () async {
    final repository = StampCatalogRepository();
    final entries = await repository.load();

    expect(entries.length, 9);
    expect(entries.map((e) => e.locationId), contains('wallys-1'));
    final wallys1 = entries.firstWhere((e) => e.locationId == 'wallys-1');
    expect(wallys1.title, "1 Wally's Walk");
    expect(wallys1.mapRef, 'K27');
    expect(wallys1.stampAsset, 'assets/stamps/wallys-1.png');
  });

  test('caches the result after the first load', () async {
    final repository = StampCatalogRepository();
    final first = await repository.load();
    final second = await repository.load();
    expect(identical(first, second), isTrue);
  });
}
