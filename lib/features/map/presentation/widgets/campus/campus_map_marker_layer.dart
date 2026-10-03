import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/features/map/domain/entities/building.dart';
import 'package:mq_navigation/features/map/domain/services/campus_projection.dart';

/// Renders building markers on the campus map.
class CampusMapMarkerLayer extends StatelessWidget {
  const CampusMapMarkerLayer({
    super.key,
    required this.visibleBuildings,
    required this.selectedBuilding,
    required this.projection,
    required this.onSelectBuilding,
  });

  final List<Building> visibleBuildings;
  final Building? selectedBuilding;
  final CampusProjection projection;
  final ValueChanged<Building> onSelectBuilding;

  static const double _defaultMarkerWidth = 120.0;
  static const double _defaultMarkerHeight = 34.0;
  // The selected marker is a small, symmetric circular badge centred on the
  // coordinate (see [_SelectedBadge]). A square box keeps it centred.
  static const double _selectedMarkerSize = 46.0;

  @override
  Widget build(BuildContext context) {
    if (visibleBuildings.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedId = selectedBuilding?.id;

    // Render the selected building LAST so its badge always draws on top of
    // any nearby standard markers.
    final ordered = [
      for (final b in visibleBuildings)
        if (b.id != selectedId) b,
      for (final b in visibleBuildings)
        if (b.id == selectedId) b,
    ];

    return MarkerLayer(
      markers: ordered.map((building) {
        final isSelected = selectedId == building.id;
        return Marker(
          point: resolveBuildingPoint(building, projection),
          width: isSelected ? _selectedMarkerSize : _defaultMarkerWidth,
          height: isSelected ? _selectedMarkerSize : _defaultMarkerHeight,
          // Both variants anchor at [Alignment.center] on a compact, roughly
          // symmetric child, so the marker centre *is* the coordinate. There is
          // no tall body or offset label whose fixed pixel height would sweep
          // across the map at different zooms — so neither the selected badge
          // nor the category pills appear to drift. Consistent anchoring across
          // all marker types.
          alignment: Alignment.center,
          child: CampusBuildingMarker(
            building: building,
            isSelected: isSelected,
            onTap: () => onSelectBuilding(building),
          ),
        );
      }).toList(),
    );
  }
}

/// Resolves the map-space point for a building, preferring campus pixel
/// coordinates when available and falling back to GPS projection.
latlong.LatLng resolveBuildingPoint(
  Building building,
  CampusProjection projection,
) {
  final campusPoint = building.campusPoint;
  if (campusPoint != null) {
    return projection.buildingPixelToMapPoint(campusPoint);
  }

  return projection.gpsToMapPoint(
    latitude: building.routingLatitude ?? building.latitude!,
    longitude: building.routingLongitude ?? building.longitude!,
  );
}

/// A single building marker: a flat circular badge when selected, or a
/// lightweight label-chip + dot otherwise.
class CampusBuildingMarker extends StatelessWidget {
  const CampusBuildingMarker({
    super.key,
    required this.building,
    required this.isSelected,
    required this.onTap,
  });

  final Building building;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: building.name,
      child: GestureDetector(
        onTap: onTap,
        child: isSelected ? const _SelectedBadge() : _buildDefault(context),
      ),
    );
  }

  /// Standard / category marker — a compact, high-contrast **dark pill** with
  /// the building code in white. The old version was a white chip, which
  /// vanished against the map's pale roads and labels; a dark charcoal pill
  /// with a white hairline ring reads instantly as an interactive marker and
  /// is distinct from the solid-red selected badge. Centred on the coordinate
  /// (see the layer's [Alignment.center]) so it stays put across zoom.
  Widget _buildDefault(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MqSpacing.space3,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: MqColors.charcoal800,
          borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: MqColors.charcoal800.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          building.code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Flat, symmetric destination badge for the selected building.
///
/// **Why a centred circle instead of a pin:** a pin is anchored at its tip,
/// but its body/label extend upward — at low zoom those fixed *pixels* cover a
/// large real-world area, so the head appears to slide over different buildings
/// (the "drift" reported across zoom levels). A circle anchored at
/// [Alignment.center] is symmetric about the exact coordinate, so every part of
/// it sits on the point and it reads as completely fixed at all zoom levels.
/// The building name is shown in the bottom info sheet, so no floating label is
/// needed on the marker itself.
class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: MqColors.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: MqColors.charcoal800.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // A small white centre dot reinforces "this exact spot" and keeps the
      // badge perfectly symmetric (no directional glyph to bias the eye).
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
