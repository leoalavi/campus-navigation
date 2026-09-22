import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/features/indoor/data/repositories/indoor_repository.dart';
import 'package:mq_navigation/features/indoor/domain/models/indoor_manifest.dart';

final indoorRepositoryProvider = Provider<IndoorRepository>(
  (ref) => IndoorRepository(),
);

/// Building ids that ship a 360° tour. Used to decide whether to offer the
/// "360° view" affordance on a building, without loading any panorama.
final indoorTourIdsProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(indoorRepositoryProvider).tourIds(),
);

/// Scene count for a building's tour, or `null` when it ships none. Drives
/// whether the 360° affordance is offered at all, so it must not load imagery.
final indoorTourSceneCountProvider = FutureProvider.family<int?, String>(
  (ref, buildingId) =>
      ref.watch(indoorRepositoryProvider).sceneCount(buildingId),
);

/// The tour for a building, or `null` when it has none.
final indoorManifestProvider = FutureProvider.family<IndoorManifest?, String>(
  (ref, buildingId) => ref.watch(indoorRepositoryProvider).load(buildingId),
);
