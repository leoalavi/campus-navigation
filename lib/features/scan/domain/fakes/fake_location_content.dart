import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_navigation/features/scan/domain/contracts/location_content.dart';

final fakeLocationContentProvider = Provider.family<LocationContent?, String>((
  ref,
  locationId,
) {
  return LocationContent(
    locationId: locationId,
    title: locationId == 'lib-01' ? 'Library' : 'Location $locationId',
    heroImageAsset: 'assets/images/placeholder_hero.png',
    shortDescription: 'A featured campus location.',
    buildingId: locationId == 'lib-01' ? 'C3A' : null,
    fullScheduleUrl: null,
  );
});
