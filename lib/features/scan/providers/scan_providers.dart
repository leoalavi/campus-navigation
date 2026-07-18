import 'package:flutter_riverpod/flutter_riverpod.dart';
// Re-export trail providers so existing `scan_providers.dart` imports of
// trailRepositoryProvider / trailManifestProvider keep resolving.
export 'package:mq_journey/features/scan/providers/trail_providers.dart';
import 'package:mq_journey/features/scan/data/adapters/open_day_schedule_provider_adapter.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/data/adapters/registry_location_content_provider.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_my_day_api_adapter.dart';
import 'package:mq_journey/features/scan/data/repositories/indoor_repository.dart';
import 'package:mq_journey/features/scan/data/repositories/buildings_repository.dart';
import 'package:mq_journey/features/scan/data/repositories/stamp_catalog_repository.dart';
import 'package:mq_journey/features/scan/domain/contracts/my_day_api.dart';
import 'package:mq_journey/features/scan/domain/contracts/schedule_provider.dart';
import 'package:mq_journey/features/scan/domain/contracts/location_content.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_schedule_provider.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/features/scan/domain/models/buildings_registry.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_public_key_registry.dart';
import 'package:mq_journey/features/scan/domain/qr/qr_signature_verifier.dart';

final indoorRepositoryProvider = Provider<IndoorRepository>(
  (ref) => IndoorRepository(),
);
final buildingsRepositoryProvider = Provider<BuildingsRepository>(
  (ref) => BuildingsRepository(),
);

final qrSignatureVerifierProvider = Provider<QrSignatureVerifier>((ref) {
  return QrSignatureVerifier(publicKeys: qrPublicKeys);
});

final buildingsRegistryProvider = FutureProvider<BuildingsRegistry>((ref) {
  return ref.read(buildingsRepositoryProvider).load();
});

final indoorManifestProvider = FutureProvider.family<IndoorManifest?, String>((
  ref,
  buildingId,
) {
  return ref.read(indoorRepositoryProvider).load(buildingId);
});

final locationContentProvider = Provider.family<LocationContent?, String>((
  ref,
  locationId,
) {
  return ref.watch(registryLocationContentProvider(locationId));
});

final scheduleProvider = Provider<ScheduleProvider>((ref) {
  final data = ref.watch(openDayDataProvider).value;
  final now = ref.watch(openDayNowProvider);
  if (data == null) return FakeScheduleProvider();
  return OpenDayScheduleProviderAdapter(allEvents: data.events, now: now);
});

final myDayApiProvider = Provider<MyDayApi>((ref) {
  return SettingsMyDayApiAdapter(ref);
});

final visitedStateProvider = StreamProvider.family<VisitedState, String>((
  ref,
  locationId,
) {
  return ref.watch(progressApiProvider).watch(locationId);
});

final stampCatalogRepositoryProvider = Provider<StampCatalogRepository>(
  (ref) => StampCatalogRepository(),
);

final stampCatalogProvider = FutureProvider<List<StampCatalogEntry>>((ref) {
  return ref.watch(stampCatalogRepositoryProvider).load();
});
