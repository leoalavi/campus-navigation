import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:mq_journey/core/logging/app_logger.dart';

const campusOfflineStoreName = 'campus_offline_tiles';

/// Set to true only after [FMTCObjectBoxBackend.initialise] completes
/// successfully. When false, [OfflineMapsService.tileProvider] uses
/// [NetworkTileProvider] so maps still load (sandboxed macOS often fails
/// ObjectBox init unless an application group is configured).
bool _fmtcObjectBoxBackendReady = false;

final offlineMapsServiceProvider = Provider<OfflineMapsService>((ref) {
  return const OfflineMapsService();
});

class OfflineMapsService {
  const OfflineMapsService();

  /// Whether tile caching via FMTC is available (native ObjectBox initialised).
  bool get isFmtcBackendReady => _fmtcObjectBoxBackendReady;

  Future<void> ensureStore() async {
    if (!_fmtcObjectBoxBackendReady) {
      return;
    }
    await const FMTCStore(campusOfflineStoreName).manage.create();
  }

  TileProvider tileProvider() {
    if (!_fmtcObjectBoxBackendReady) {
      return NetworkTileProvider();
    }
    return FMTCTileProvider(stores: const {campusOfflineStoreName: null});
  }

  /// Downloads the campus tile region. Returns true only when the download
  /// ran to completion, so callers can persist a "downloaded" state and stop
  /// offering the download as if it never happened.
  Future<bool> downloadCampusTiles() async {
    // ObjectBox is optional and expensive native/FFI work. Initialise it only
    // when the user asks for an offline download so it cannot delay every
    // launch for users who never use this feature.
    if (!isFmtcBackendReady) {
      await initializeBackend();
    }
    if (!isFmtcBackendReady) {
      AppLogger.warning(
        'Offline campus tile download skipped: FMTC ObjectBox backend is not '
        'initialised (e.g. macOS App Sandbox may need an application group).',
      );
      return false;
    }
    await ensureStore();

    final tileLayer = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'io.mqjourney.mq_journey',
    );
    final region = RectangleRegion(
      LatLngBounds(
        const LatLng(-33.792, 151.087),
        const LatLng(-33.756, 151.133),
      ),
    ).toDownloadable(minZoom: 15, maxZoom: 18, options: tileLayer);

    final streams = const FMTCStore(
      campusOfflineStoreName,
    ).download.startForeground(region: region, skipExistingTiles: true);
    await streams.downloadProgress.last;
    return true;
  }

  Future<void> initializeBackend() async {
    _fmtcObjectBoxBackendReady = false;
    // FMTC's ObjectBox backend uses FFI and is not supported on web.
    if (kIsWeb) {
      return;
    }
    try {
      // Bound the user-triggered download setup so a hung/corrupted ObjectBox
      // store surfaces a failure instead of leaving an endless spinner.
      await FMTCObjectBoxBackend().initialise().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          AppLogger.warning(
            'Offline map backend init timed out after 8 s — '
            'continuing with network-only tiles.',
          );
        },
      );
      _fmtcObjectBoxBackendReady = true;
    } catch (error, stackTrace) {
      // ObjectBox can throw platform exceptions on first launch, after a
      // crash-corrupted database, or in certain iOS sandbox configurations.
      // We intentionally swallow the exception so the app remains usable
      // with online-only tiles.
      AppLogger.warning(
        'Offline map backend init skipped — desktop OSM will use online tiles '
        'only until ObjectBox can start (check macOS sandbox / app group). '
        'If this persists after a clean install the ObjectBox store file may '
        'be corrupted; deleting the app and reinstalling should clear it.',
        error,
        stackTrace,
      );
    }
  }
}
