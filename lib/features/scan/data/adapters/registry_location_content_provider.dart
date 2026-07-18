import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

final registryLocationContentProvider =
    Provider.family<LocationContent?, String>((ref, locationId) {
      final manifest = ref.watch(trailManifestProvider).value;
      final registry = ref.watch(buildingsRegistryProvider).value;
      if (manifest == null || registry == null) return null;

      final location = manifest.byId(locationId);
      if (location == null) return null;

      final building = location.buildingId != null
          ? registry.byCode(location.buildingId!)
          : null;
      return LocationContent(
        locationId: locationId,
        title: building?.name.isNotEmpty == true
            ? building!.name
            : location.title,
        heroImageAsset: 'assets/images/placeholder_hero.png',
        // Prefer the trail's own blurb (the curated Open Day copy); fall back to
        // the building registry description, then a generic line.
        shortDescription: location.description?.isNotEmpty == true
            ? location.description!
            : (building?.description.isNotEmpty == true
                  ? building!.description
                  : 'A featured Macquarie University location.'),
        buildingId: location.buildingId,
        mapBuildingCode: location.mapBuildingCode,
        fullScheduleUrl: null,
      );
    });
