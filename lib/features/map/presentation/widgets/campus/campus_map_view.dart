import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/core/utils/haptics.dart';
import 'package:mq_journey/features/map/data/datasources/map_assets_source.dart';
import 'package:mq_journey/features/map/data/mappers/campus_projection_impl.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/domain/entities/campus_overlay_meta.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/map/domain/services/campus_projection.dart';
import 'package:mq_journey/features/map/presentation/widgets/campus/campus_map_location_layer.dart';
import 'package:mq_journey/features/map/presentation/widgets/campus/campus_map_marker_layer.dart';
import 'package:mq_journey/features/map/presentation/widgets/campus/campus_map_overlay.dart';
import 'package:mq_journey/features/map/presentation/widgets/campus/campus_map_route_layer.dart';
import 'package:mq_journey/features/map/presentation/widgets/campus/campus_overlay_layers.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_view_helpers.dart';
import 'package:mq_journey/shared/widgets/mq_card.dart';
import 'package:share_plus/share_plus.dart';

/// The primary `flutter_map` renderer for the 2D illustrated campus map.
///
/// Orchestrates several specialized layers (overlays, markers, routes) and
/// handles the lifecycle of the map projection. It blocks rendering until
/// [CampusOverlayMeta] is loaded from assets, ensuring the map is always
/// correctly calibrated to real-world GPS coordinates.
class CampusMapView extends ConsumerStatefulWidget {
  const CampusMapView({
    super.key,
    required this.searchResults,
    required this.searchQuery,
    required this.selectedBuilding,
    required this.route,
    required this.currentLocation,
    required this.locationCenterRequestToken,
    required this.isNavigating,
    required this.onSelectBuilding,
    this.activeOverlayIds = const {},
  });

  final List<Building> searchResults;
  final String searchQuery;
  final Building? selectedBuilding;
  final MapRoute? route;
  final LocationSample? currentLocation;
  final int locationCenterRequestToken;
  final bool isNavigating;
  final ValueChanged<Building> onSelectBuilding;
  final Set<String> activeOverlayIds;

  @override
  ConsumerState<CampusMapView> createState() => _CampusMapViewState();
}

class _CampusMapViewState extends ConsumerState<CampusMapView> {
  final MapController _controller = MapController();
  late final Future<CampusOverlayMeta> _metaFuture;
  CampusProjection? _projection;

  /// True once `FlutterMap` has fired `onMapReady`. `MapController.move()`
  /// throws ("You need to have the FlutterMap widget rendered at least once
  /// before using the MapController") if called before that — which happens
  /// when the Map branch is deep-linked to with a building already selected
  /// (e.g. from an Open Day session's "View in Campus Map"): `didUpdateWidget`
  /// runs `_moveMap` before the offstage map has laid out. `_handleMapReady`
  /// already repositions to the selected building once ready, so moves
  /// requested before then are safely skipped.
  bool _mapReady = false;
  static const double _mapMinZoom = -4.0;
  static const double _mapHardMaxZoom = -2.2;
  @override
  void initState() {
    super.initState();
    _metaFuture = ref.read(mapAssetsSourceProvider).loadCampusOverlayMeta();
    _metaFuture.then((meta) {
      if (!mounted) {
        return;
      }
      _projection = CampusProjectionImpl(meta);
    });
  }

  @override
  void didUpdateWidget(covariant CampusMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final projection = _projection;
    if (projection == null) {
      return;
    }

    // Explicit location-center requests should always move camera, even when
    // location coordinates have not changed.
    if (widget.locationCenterRequestToken !=
        oldWidget.locationCenterRequestToken) {
      final location = widget.currentLocation;
      if (location != null) {
        _moveMap(
          projection.gpsToMapPoint(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      }
      return;
    }

    // Follow user during active navigation
    if (widget.isNavigating) {
      final newLocation = widget.currentLocation;
      final oldLocation = oldWidget.currentLocation;
      if (newLocation != null &&
          (oldLocation == null ||
              newLocation.latitude != oldLocation.latitude ||
              newLocation.longitude != oldLocation.longitude)) {
        _moveMap(
          projection.gpsToMapPoint(
            latitude: newLocation.latitude,
            longitude: newLocation.longitude,
          ),
        );
        return;
      }
    }

    if (widget.selectedBuilding != null &&
        widget.selectedBuilding?.id != oldWidget.selectedBuilding?.id) {
      _moveMap(
        resolveBuildingPoint(widget.selectedBuilding!, projection),
        zoom: _mapHardMaxZoom,
      );
      return;
    }
  }

  void _shareCustomLocation({
    required BuildContext context,
    required double latitude,
    required double longitude,
  }) {
    final l10n = AppLocalizations.of(context)!;
    MqHaptics.heavy(true);
    final uri = Uri(
      scheme: 'io.mqjourney',
      host: 'meet',
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      },
    );
    SharePlus.instance.share(
      ShareParams(text: '${l10n.appName} ${uri.toString()}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CampusOverlayMeta>(
      future: _metaFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final l10n = AppLocalizations.of(context)!;
          return MqCard(
            child: Text(
              l10n.campusOverlayUnavailable,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final meta = snapshot.data;
        if (meta == null) {
          return const Center(
            child: CircularProgressIndicator(color: MqColors.red),
          );
        }

        final projection = _projection ?? CampusProjectionImpl(meta);
        _projection = projection;
        // Marker filter — accept any building with usable coordinates.
        //
        // Previously we passed `requireCampusCoordinates: true`, which
        // restricted the list to buildings with baked-in pixel (campusX
        // / campusY) coordinates. That silently dropped every newly
        // added building from the markers, because the dataset for new
        // entries only carries GPS coordinates. The user saw the camera
        // auto-zoom to the building (the focus path uses the GPS-to-map
        // projection in [resolveBuildingPoint]) but no marker rendered.
        //
        // [CampusMapMarkerLayer.resolveBuildingPoint] already handles
        // both cases — preferring `campusPoint` when present and
        // falling back to `projection.gpsToMapPoint` otherwise — so
        // simply allowing GPS-only buildings here is the complete fix.
        final visibleBuildings = resolveVisibleBuildings(
          searchResults: widget.searchResults,
          searchQuery: widget.searchQuery,
          selectedBuilding: widget.selectedBuilding,
        );
        final rawRoutePoints = widget.route == null
            ? const <LocationSample>[]
            : resolveRoutePoints(widget.route!);
        final routePoints = rawRoutePoints
            .map(
              (point) => projection.gpsToMapPoint(
                latitude: point.latitude,
                longitude: point.longitude,
              ),
            )
            .toList();
        final bounds = LatLngBounds(
          latlong.LatLng(meta.mapSouth, meta.mapWest),
          latlong.LatLng(meta.mapNorth, meta.mapEast),
        );

        // Sanity check bounds to avoid 'Invalid argument: 0' (log(0)) in flutter_map
        // if bounds width/height is effectively zero.
        final bool isValidBounds =
            (meta.mapNorth - meta.mapSouth).abs() > 0.000001 &&
            (meta.mapEast - meta.mapWest).abs() > 0.000001;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Guard against invalid constraints (e.g., during initial layout pass or zero-sized parent)
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
              return const SizedBox.shrink();
            }

            // Calculate safe padding.
            // If constraints are infinite (e.g. inside unconstrained parent), fall back to safe constant.
            final double horizontalPadding = constraints.hasInfiniteWidth
                ? MqSpacing.space4
                : constraints.maxWidth * 0.15;
            final double verticalPadding = constraints.hasInfiniteHeight
                ? MqSpacing.space4
                : constraints.maxHeight * 0.15;
            // Clarity-safe zoom bounds for the illustrated campus raster.
            // - `mapMinZoom` (-4) keeps the campus from collapsing into a
            //   tiny island of empty space when the user pinches out.
            // - `mapMaxZoom` caps zoom-in below the point at which the
            //   raster visibly pixelates. Tightened to 0.0 so users can't
            //   zoom in far enough to degrade the underlying campus image.
            //   Lower of metadata maxZoom and this hard cap wins.
            const double initialFitMaxZoom = -3.6;
            final double mapMaxZoom = meta.maxZoom < _mapHardMaxZoom
                ? meta.maxZoom
                : _mapHardMaxZoom;

            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? const [MqColors.charcoal800, MqColors.charcoal800]
                      : const [MqColors.sand100, MqColors.alabaster],
                ),
              ),
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  crs: const CrsSimple(),
                  initialCenter: latlong.LatLng(
                    meta.centerLatitude,
                    meta.centerLongitude,
                  ),
                  initialZoom: -3.6,
                  initialCameraFit: isValidBounds
                      ? CameraFit.bounds(
                          bounds: bounds,
                          // Dynamic padding (15% of screen) to frame the campus,
                          // ensuring it doesn't touch edges or crash on small screens.
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          // Cap the initial fit zoom lower than before so first load
                          // is about 2x more zoomed out (one additional zoom level).
                          maxZoom: initialFitMaxZoom,
                          // Keep fit min zoom consistent with map min zoom to avoid
                          // invalid clamp ranges in flutter_map internals.
                          minZoom: _mapMinZoom,
                        )
                      : null,
                  // Hard zoom bounds (see `mapMinZoom`/`mapMaxZoom` above).
                  minZoom: _mapMinZoom,
                  maxZoom: mapMaxZoom,
                  // Constrain the camera to the campus bounds so users don't pan into the void.
                  cameraConstraint: CameraConstraint.contain(bounds: bounds),
                  onLongPress: (tapPosition, latLng) {
                    _shareCustomLocation(
                      context: context,
                      latitude: latLng.latitude,
                      longitude: latLng.longitude,
                    );
                  },
                  onMapReady: () => _handleMapReady(meta, projection),
                ),
                children: [
                  CampusMapOverlay(meta: meta),
                  CampusOverlayLayers(
                    activeOverlayIds: widget.activeOverlayIds,
                    meta: meta,
                  ),
                  if (routePoints.isNotEmpty)
                    CampusMapRouteLayer(
                      route: widget.route!,
                      routePoints: routePoints,
                      rawRoutePoints: rawRoutePoints,
                      isNavigating: widget.isNavigating,
                      currentLocation: widget.currentLocation,
                    ),
                  CampusMapMarkerLayer(
                    visibleBuildings: visibleBuildings,
                    selectedBuilding: widget.selectedBuilding,
                    projection: projection,
                    onSelectBuilding: widget.onSelectBuilding,
                  ),
                  CampusMapLocationLayer(
                    currentLocation: widget.currentLocation,
                    projection: projection,
                    route: widget.route,
                    routePoints: routePoints,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleMapReady(CampusOverlayMeta meta, CampusProjection projection) {
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      // Only override the initial camera fit when a building is selected.
      // Otherwise let the CameraFit.bounds show the full campus.
      if (widget.selectedBuilding case final selectedBuilding?) {
        _moveMap(
          resolveBuildingPoint(selectedBuilding, projection),
          zoom: _mapHardMaxZoom,
        );
      }
    });
  }

  void _moveMap(latlong.LatLng point, {double? zoom}) {
    // The FlutterMap must have rendered at least once before its controller
    // can move; before then `_handleMapReady` handles the initial position.
    if (!_mapReady) return;
    final targetZoom = (zoom ?? _currentZoom(fallback: _mapHardMaxZoom)).clamp(
      _mapMinZoom,
      _mapHardMaxZoom,
    );
    _controller.move(point, targetZoom);
  }

  double _currentZoom({required double fallback}) {
    try {
      return _controller.camera.zoom;
    } on StateError {
      return fallback;
    }
  }
}
