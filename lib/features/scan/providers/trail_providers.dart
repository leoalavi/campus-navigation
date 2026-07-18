import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/features/scan/data/repositories/trail_repository.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';

/// Trail data providers, kept in their own file so features that only need
/// the Open Day trail (e.g. the Open Day "Your Day" list resolving scanned
/// venues) can depend on them WITHOUT importing `scan_providers.dart` —
/// which imports the Open Day layer and would create an import cycle.
///
/// `scan_providers.dart` re-exports these, so existing imports keep working.
final trailRepositoryProvider = Provider<TrailRepository>(
  (ref) => TrailRepository(),
);

final trailManifestProvider = FutureProvider<TrailManifest>((ref) {
  return ref.read(trailRepositoryProvider).load();
});
