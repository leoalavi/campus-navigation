import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/map/data/datasources/location_source.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/map/presentation/widgets/ar_building_picker.dart';
import 'package:mq_journey/features/map/presentation/widgets/building_actions_sheet.dart';
import 'package:mq_journey/features/map/presentation/widgets/building_search_sheet.dart';
import 'package:mq_journey/features/map/presentation/widgets/campus/campus_map_view.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_shell.dart';
import 'package:mq_journey/features/map/presentation/widgets/overlay_picker_sheet.dart';
import 'package:mq_journey/features/scan/presentation/pages/indoor_preview_page.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/mq_button.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({
    super.key,
    this.initialBuildingId,
    this.initialSearchQuery,
    this.meetLat,
    this.meetLng,
  });

  final String? initialBuildingId;
  final String? initialSearchQuery;
  final double? meetLat;
  final double? meetLng;

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  MapMode _mapMode = MapMode.campusMap;

  Widget? _buildArContent() {
    if (_mapMode != MapMode.ar) return null;
    final state = ref.read(mapControllerProvider).value;
    final selected = state?.selectedBuilding;
    final buildingCode = selected?.code;

    if (buildingCode != null) {
      return IndoorPreviewPage(buildingId: buildingCode);
    }

    return ArBuildingPicker(
      onSelect: (buildingId) {
        ref.read(mapControllerProvider.notifier).selectBuildingById(buildingId);
        setState(() {});
      },
    );
  }

  Future<void> _openSearchSheet() async {
    final building = await showModalBottomSheet<Building>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BuildingSearchSheet(),
    );
    if (!mounted) return;
    if (building != null) {
      await BuildingActionsSheet.show(
        context,
        buildingId: building.id,
        buildingName: building.name,
      );
    }
  }

  void _openOverlayPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? MqColors.charcoal800
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MqSpacing.radiusXl),
        ),
      ),
      builder: (_) => const OverlayPickerSheet(),
    );
  }

  void _handleNavigationParams(MapState mapState) {
    final buildingId = widget.initialBuildingId;
    final meetLat = widget.meetLat;
    final meetLng = widget.meetLng;
    final searchQuery = widget.initialSearchQuery;

    if (meetLat != null && meetLng != null) {
      final meetPointCode =
          '${meetLat.toStringAsFixed(5)}, ${meetLng.toStringAsFixed(5)}';
      if (mapState.selectedBuilding?.code != meetPointCode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(mapControllerProvider.notifier)
              .selectMeetPoint(latitude: meetLat, longitude: meetLng);
        });
      }
    } else if (buildingId != null) {
      final selectedId = mapState.selectedBuilding?.id.toUpperCase();
      final selectedCode = mapState.selectedBuilding?.code.toUpperCase();
      final upperId = buildingId.toUpperCase();
      if (selectedId != upperId && selectedCode != upperId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(mapControllerProvider.notifier)
              .selectBuildingById(buildingId);
        });
      }
    } else if (searchQuery != null && searchQuery.isNotEmpty) {
      if (mapState.searchQuery != searchQuery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(mapControllerProvider.notifier)
              .updateSearchQuery(searchQuery);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = ref.read(mapControllerProvider).value;
      if (currentState != null) {
        _handleNavigationParams(currentState);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentState = ref.read(mapControllerProvider).value;
    if (currentState != null) {
      _handleNavigationParams(currentState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(mapControllerProvider);
    final isDark = context.isDarkMode;

    ref.listen<AsyncValue<MapState>>(mapControllerProvider, (previous, next) {
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
      if (!isCurrent) return;

      if (next.hasValue) {
        final mapState = next.value!;

        if (previous == null || !previous.hasValue) {
          _handleNavigationParams(mapState);
          return;
        }

        final selectedBuilding = mapState.selectedBuilding;
        if (!context.mounted) return;
        final location = GoRouterState.of(context).matchedLocation;

        if (selectedBuilding != null &&
            !selectedBuilding.id.startsWith('meet_')) {
          if (!location.contains('building=')) {
            context.goNamed(
              RouteNames.map,
              queryParameters: {'building': selectedBuilding.id},
            );
          }
        } else {
          if (location.contains('building=')) {
            context.goNamed(RouteNames.map);
          }
        }
      }
    });

    if (state.hasValue) {
      final selectedBuilding = state.value!.selectedBuilding;
      if (selectedBuilding != null &&
          !selectedBuilding.id.startsWith('meet_')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
          if (!isCurrent) return;

          final location = GoRouterState.of(context).matchedLocation;
          final hasBuildingParam = GoRouterState.of(
            context,
          ).uri.queryParameters.containsKey('building');
          if (location == '/map' && !hasBuildingParam) {
            ref.read(mapControllerProvider.notifier).clearSelection();
          }
        });
      }
    }

    return Scaffold(
      body: state.when(
        data: (mapState) {
          final controller = ref.read(mapControllerProvider.notifier);
          final permissionState = mapState.permissionState;
          final isPermissionBlocked =
              permissionState == LocationPermissionState.denied ||
              permissionState == LocationPermissionState.deniedForever ||
              permissionState == LocationPermissionState.servicesDisabled;

          final isCategoryBrowse =
              mapState.searchQuery.trim().isNotEmpty &&
              mapState.selectedBuilding == null &&
              mapState.searchResults.length > 1;

          final normalizedQuery = mapState.searchQuery.trim().toLowerCase();

          final isFacultyCategory = normalizedQuery == 'faculty';
          final facultyTopLevel =
              isFacultyCategory && mapState.selectedFacultyGroup == null;
          final facultySubLevel =
              isFacultyCategory && mapState.selectedFacultyGroup != null;
          final facultyBuildings = facultySubLevel
              ? mapState.searchResults
                    .where(
                      (b) => b.facultyGroup == mapState.selectedFacultyGroup,
                    )
                    .toList()
              : const <Building>[];

          final isStudentServicesCategory =
              normalizedQuery == 'student services';
          final studentServicesTopLevel =
              isStudentServicesCategory &&
              mapState.selectedStudentServicesGroup == null;
          final studentServicesSubLevel =
              isStudentServicesCategory &&
              mapState.selectedStudentServicesGroup != null;
          final studentServicesBuildings = studentServicesSubLevel
              ? mapState.searchResults
                    .where(
                      (b) => b.studentServicesGroups.contains(
                        mapState.selectedStudentServicesGroup,
                      ),
                    )
                    .toList()
              : const <Building>[];

          final isCampusHubCategory = normalizedQuery == 'campus hub';
          final campusHubTopLevel =
              isCampusHubCategory && mapState.selectedCampusHubGroup == null;
          final campusHubSubLevel =
              isCampusHubCategory && mapState.selectedCampusHubGroup != null;
          final campusHubBuildings = campusHubSubLevel
              ? mapState.searchResults
                    .where(
                      (b) => b.campusHubGroups.contains(
                        mapState.selectedCampusHubGroup,
                      ),
                    )
                    .toList()
              : const <Building>[];

          final List<Building> rendererSearchResults;
          if (facultySubLevel) {
            rendererSearchResults = facultyBuildings;
          } else if (studentServicesSubLevel) {
            rendererSearchResults = studentServicesBuildings;
          } else if (campusHubSubLevel) {
            rendererSearchResults = campusHubBuildings;
          } else if (facultyTopLevel ||
              studentServicesTopLevel ||
              campusHubTopLevel) {
            rendererSearchResults = const <Building>[];
          } else {
            rendererSearchResults = mapState.searchResults;
          }

          final mapView = CampusMapView(
            searchResults: rendererSearchResults,
            searchQuery: mapState.searchQuery,
            selectedBuilding: mapState.selectedBuilding,
            route: mapState.route,
            currentLocation: mapState.currentLocation,
            locationCenterRequestToken: mapState.locationCenterRequestToken,
            isNavigating: mapState.isNavigating,
            onSelectBuilding: controller.selectBuilding,
            activeOverlayIds: mapState.activeOverlayIds,
          );

          return MapShell(
            mapView: mapView,
            onCenterOnLocation: controller.centerOnCurrentLocation,
            onOpenSearch: _openSearchSheet,
            onOpenOverlayPicker: _openOverlayPicker,
            filterChips: _CategoryFilterChips(
              activeQuery: mapState.searchQuery,
              onSelect: controller.updateSearchQuery,
            ),
            banner: mapState.error == null
                ? null
                : _MapErrorBanner(
                    title: _errorTitle(l10n, mapState.error!),
                    message: _errorMessage(l10n, mapState.error!),
                    isPermissionBlocked: isPermissionBlocked,
                    onCenterOnLocation: controller.centerOnCurrentLocation,
                    onOpenSettings:
                        permissionState ==
                            LocationPermissionState.servicesDisabled
                        ? controller.openLocationSettings
                        : controller.openAppSettings,
                  ),
            footer: mapState.selectedBuilding != null
                ? _CampusBuildingInfoPanel(
                    selectedBuilding: mapState.selectedBuilding!,
                    onClearSelection: controller.clearSelection,
                  )
                : facultyTopLevel
                ? _BrowseGroupPanel<FacultyGroup>(
                    title: l10n.home_faculty,
                    leadingIcon: Icons.school,
                    groups: FacultyGroup.values,
                    countByGroup: {
                      for (final g in FacultyGroup.values)
                        g: mapState.searchResults
                            .where(
                              (b) =>
                                  b.facultyGroup == g &&
                                  b.latitude != null &&
                                  b.longitude != null,
                            )
                            .length,
                    },
                    labelOf: (g) {
                      switch (g) {
                        case FacultyGroup.arts:
                          return l10n.faculty_arts_label;
                        case FacultyGroup.business:
                          return l10n.faculty_business_label;
                        case FacultyGroup.mhhs:
                          return l10n.faculty_mhhs_label;
                        case FacultyGroup.scienceEngineering:
                          return l10n.faculty_scienceEngineering_label;
                      }
                    },
                    descriptionOf: (g) {
                      switch (g) {
                        case FacultyGroup.arts:
                          return l10n.faculty_arts_desc;
                        case FacultyGroup.business:
                          return l10n.faculty_business_desc;
                        case FacultyGroup.mhhs:
                          return l10n.faculty_mhhs_desc;
                        case FacultyGroup.scienceEngineering:
                          return l10n.faculty_scienceEngineering_desc;
                      }
                    },
                    onSelectGroup: controller.selectFacultyGroup,
                    onClear: controller.clearCategoryBrowse,
                  )
                : facultySubLevel
                ? _CategoryBuildingList(
                    buildings: facultyBuildings,
                    searchQuery: () {
                      switch (mapState.selectedFacultyGroup!) {
                        case FacultyGroup.arts:
                          return l10n.faculty_arts_label;
                        case FacultyGroup.business:
                          return l10n.faculty_business_label;
                        case FacultyGroup.mhhs:
                          return l10n.faculty_mhhs_label;
                        case FacultyGroup.scienceEngineering:
                          return l10n.faculty_scienceEngineering_label;
                      }
                    }(),
                    onSelectBuilding: controller.selectBuilding,
                    onBack: () => controller.selectFacultyGroup(null),
                    onClear: controller.clearCategoryBrowse,
                  )
                : studentServicesTopLevel
                ? _BrowseGroupPanel<StudentServicesGroup>(
                    title: l10n.home_studentServices,
                    leadingIcon: Icons.support_agent,
                    groups: StudentServicesGroup.values,
                    countByGroup: {
                      for (final g in StudentServicesGroup.values)
                        g: mapState.searchResults
                            .where(
                              (b) =>
                                  b.studentServicesGroups.contains(g) &&
                                  b.latitude != null &&
                                  b.longitude != null,
                            )
                            .length,
                    },
                    labelOf: (g) {
                      switch (g) {
                        case StudentServicesGroup.support:
                          return l10n.services_support_label;
                        case StudentServicesGroup.admin:
                          return l10n.services_admin_label;
                        case StudentServicesGroup.academic:
                          return l10n.services_academic_label;
                        case StudentServicesGroup.it:
                          return l10n.services_it_label;
                        case StudentServicesGroup.security:
                          return l10n.services_security_label;
                        case StudentServicesGroup.careers:
                          return l10n.services_careers_label;
                        case StudentServicesGroup.inclusion:
                          return l10n.services_inclusion_label;
                      }
                    },
                    descriptionOf: (g) {
                      switch (g) {
                        case StudentServicesGroup.support:
                          return l10n.services_support_desc;
                        case StudentServicesGroup.admin:
                          return l10n.services_admin_desc;
                        case StudentServicesGroup.academic:
                          return l10n.services_academic_desc;
                        case StudentServicesGroup.it:
                          return l10n.services_it_desc;
                        case StudentServicesGroup.security:
                          return l10n.services_security_desc;
                        case StudentServicesGroup.careers:
                          return l10n.services_careers_desc;
                        case StudentServicesGroup.inclusion:
                          return l10n.services_inclusion_desc;
                      }
                    },
                    onSelectGroup: controller.selectStudentServicesGroup,
                    onClear: controller.clearCategoryBrowse,
                  )
                : studentServicesSubLevel
                ? _CategoryBuildingList(
                    buildings: studentServicesBuildings,
                    searchQuery: () {
                      switch (mapState.selectedStudentServicesGroup!) {
                        case StudentServicesGroup.support:
                          return l10n.services_support_label;
                        case StudentServicesGroup.admin:
                          return l10n.services_admin_label;
                        case StudentServicesGroup.academic:
                          return l10n.services_academic_label;
                        case StudentServicesGroup.it:
                          return l10n.services_it_label;
                        case StudentServicesGroup.security:
                          return l10n.services_security_label;
                        case StudentServicesGroup.careers:
                          return l10n.services_careers_label;
                        case StudentServicesGroup.inclusion:
                          return l10n.services_inclusion_label;
                      }
                    }(),
                    onSelectBuilding: controller.selectBuilding,
                    onBack: () => controller.selectStudentServicesGroup(null),
                    onClear: controller.clearCategoryBrowse,
                  )
                : campusHubTopLevel
                ? _BrowseGroupPanel<CampusHubGroup>(
                    title: l10n.home_campusHub,
                    leadingIcon: Icons.account_balance,
                    groups: CampusHubGroup.values,
                    countByGroup: {
                      for (final g in CampusHubGroup.values)
                        g: mapState.searchResults
                            .where(
                              (b) =>
                                  b.campusHubGroups.contains(g) &&
                                  b.latitude != null &&
                                  b.longitude != null,
                            )
                            .length,
                    },
                    labelOf: (g) {
                      switch (g) {
                        case CampusHubGroup.accommodation:
                          return l10n.hub_accommodation_label;
                        case CampusHubGroup.sport:
                          return l10n.hub_sport_label;
                        case CampusHubGroup.study:
                          return l10n.hub_study_label;
                        case CampusHubGroup.museums:
                          return l10n.hub_museums_label;
                        case CampusHubGroup.studentLife:
                          return l10n.hub_studentLife_label;
                        case CampusHubGroup.childcare:
                          return l10n.hub_childcare_label;
                        case CampusHubGroup.health:
                          return l10n.hub_health_label;
                        case CampusHubGroup.bike:
                          return l10n.hub_bike_label;
                        case CampusHubGroup.smoking:
                          return l10n.hub_smoking_label;
                      }
                    },
                    descriptionOf: (g) {
                      switch (g) {
                        case CampusHubGroup.accommodation:
                          return l10n.hub_accommodation_desc;
                        case CampusHubGroup.sport:
                          return l10n.hub_sport_desc;
                        case CampusHubGroup.study:
                          return l10n.hub_study_desc;
                        case CampusHubGroup.museums:
                          return l10n.hub_museums_desc;
                        case CampusHubGroup.studentLife:
                          return l10n.hub_studentLife_desc;
                        case CampusHubGroup.childcare:
                          return l10n.hub_childcare_desc;
                        case CampusHubGroup.health:
                          return l10n.hub_health_desc;
                        case CampusHubGroup.bike:
                          return l10n.hub_bike_desc;
                        case CampusHubGroup.smoking:
                          return l10n.hub_smoking_desc;
                      }
                    },
                    onSelectGroup: controller.selectCampusHubGroup,
                    onClear: controller.clearCategoryBrowse,
                  )
                : campusHubSubLevel
                ? _CategoryBuildingList(
                    buildings: campusHubBuildings,
                    searchQuery: () {
                      switch (mapState.selectedCampusHubGroup!) {
                        case CampusHubGroup.accommodation:
                          return l10n.hub_accommodation_label;
                        case CampusHubGroup.sport:
                          return l10n.hub_sport_label;
                        case CampusHubGroup.study:
                          return l10n.hub_study_label;
                        case CampusHubGroup.museums:
                          return l10n.hub_museums_label;
                        case CampusHubGroup.studentLife:
                          return l10n.hub_studentLife_label;
                        case CampusHubGroup.childcare:
                          return l10n.hub_childcare_label;
                        case CampusHubGroup.health:
                          return l10n.hub_health_label;
                        case CampusHubGroup.bike:
                          return l10n.hub_bike_label;
                        case CampusHubGroup.smoking:
                          return l10n.hub_smoking_label;
                      }
                    }(),
                    onSelectBuilding: controller.selectBuilding,
                    onBack: () => controller.selectCampusHubGroup(null),
                    onClear: controller.clearCategoryBrowse,
                  )
                : isCategoryBrowse
                ? _CategoryBuildingList(
                    buildings: mapState.searchResults,
                    searchQuery: mapState.searchQuery,
                    onSelectBuilding: controller.selectBuilding,
                    onClear: controller.clearCategoryBrowse,
                  )
                : null,
            mapMode: _mapMode,
            onMapModeChanged: (mode) => setState(() => _mapMode = mode),
            arContent: _buildArContent(),
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(MqSpacing.space8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: MqColors.error.withValues(alpha: 0.7),
                ),
                const SizedBox(height: MqSpacing.space4),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: MqColors.red),
              const SizedBox(height: MqSpacing.space4),
              Text(
                l10n.loadingBuildings,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white : MqColors.contentTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorTitle(AppLocalizations l10n, MapStateError error) {
    return switch (error) {
      MapStateError.routeUnavailable => l10n.routeUnavailable,
      MapStateError.locationServicesDisabled ||
      MapStateError.locationPermissionBlocked ||
      MapStateError.locationPermissionRequired ||
      MapStateError.locationUnsupported ||
      MapStateError.locationUnavailable => l10n.map,
    };
  }

  String _errorMessage(AppLocalizations l10n, MapStateError error) {
    return switch (error) {
      MapStateError.routeUnavailable => l10n.noRouteAvailable,
      MapStateError.locationServicesDisabled => l10n.locationServicesDisabled,
      MapStateError.locationPermissionBlocked => l10n.locationPermissionBlocked,
      MapStateError.locationPermissionRequired =>
        l10n.locationPermissionRequired,
      MapStateError.locationUnsupported => l10n.locationUnsupported,
      MapStateError.locationUnavailable => l10n.locationUnavailable,
    };
  }
}

class _MapErrorBanner extends StatelessWidget {
  const _MapErrorBanner({
    required this.title,
    required this.message,
    required this.isPermissionBlocked,
    required this.onCenterOnLocation,
    required this.onOpenSettings,
  });

  final String title;
  final String message;
  final bool isPermissionBlocked;
  final Future<void> Function() onCenterOnLocation;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(MqSpacing.space4),
      decoration: BoxDecoration(
        color: isDark
            ? MqColors.error.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
        border: Border.all(
          color: MqColors.error.withValues(alpha: isDark ? 0.34 : 0.22),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: MqColors.charcoal800.withValues(alpha: isDark ? 0.30 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: MqColors.error,
                size: 20,
              ),
              const SizedBox(width: MqSpacing.space2),
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: MqColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.space2),
          Text(
            message,
            style: context.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white : MqColors.contentSecondary,
            ),
          ),
          if (isPermissionBlocked) ...[
            const SizedBox(height: MqSpacing.space3),
            Wrap(
              spacing: MqSpacing.space2,
              runSpacing: MqSpacing.space2,
              children: [
                MqButton(
                  label: l10n.centerOnLocation,
                  isExpanded: false,
                  onPressed: () => onCenterOnLocation(),
                ),
                MqButton(
                  label: l10n.settings,
                  variant: MqButtonVariant.outlined,
                  isExpanded: false,
                  onPressed: () => onOpenSettings(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBuildingList extends StatelessWidget {
  const _CategoryBuildingList({
    required this.buildings,
    required this.searchQuery,
    required this.onSelectBuilding,
    required this.onClear,
    this.onBack,
  });

  final List<Building> buildings;
  final String searchQuery;
  final ValueChanged<Building> onSelectBuilding;
  final VoidCallback onClear;
  final VoidCallback? onBack;

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    final validBuildings = buildings
        .where((b) => b.latitude != null && b.longitude != null)
        .toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MqSpacing.radiusXl),
        bottom: Radius.circular(MqSpacing.radiusXl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MqSpacing.space3,
          sigmaY: MqSpacing.space3,
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: isDark
                ? MqColors.charcoal800.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MqSpacing.radiusXl),
              bottom: Radius.circular(MqSpacing.radiusXl),
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : MqColors.charcoal800.withValues(alpha: 0.06),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: MqColors.charcoal800.withValues(
                  alpha: isDark ? 0.30 : 0.10,
                ),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: MqSpacing.space3,
                ),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : MqColors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  onBack != null ? MqSpacing.space2 : MqSpacing.space4,
                  MqSpacing.space3,
                  MqSpacing.space2,
                  0,
                ),
                child: Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: isDark
                              ? Colors.white
                              : MqColors.contentSecondary,
                        ),
                        tooltip: l10n.back,
                        onPressed: onBack,
                      ),
                    Expanded(
                      child: Text(
                        '${_capitalize(searchQuery.trim())} (${validBuildings.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : MqColors.contentPrimary,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? Colors.white : MqColors.contentTertiary,
                      ),
                      tooltip: l10n.clear,
                      onPressed: onClear,
                    ),
                  ],
                ),
              ),

              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    MqSpacing.space2,
                    0,
                    MqSpacing.space2,
                    MqSpacing.space3,
                  ),
                  itemCount: validBuildings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 0),
                  itemBuilder: (context, index) {
                    final building = validBuildings[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.location_on,
                        color: MqColors.red,
                        size: 20,
                      ),
                      title: Text(
                        building.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white
                              : MqColors.contentPrimary,
                        ),
                      ),
                      subtitle: building.address != null
                          ? Text(
                              building.address!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : MqColors.charcoal600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: isDark ? Colors.white : MqColors.charcoal600,
                      ),
                      onTap: () => onSelectBuilding(building),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseGroupPanel<TGroup> extends StatelessWidget {
  const _BrowseGroupPanel({
    required this.title,
    required this.groups,
    required this.countByGroup,
    required this.labelOf,
    required this.descriptionOf,
    required this.onSelectGroup,
    required this.onClear,
    required this.leadingIcon,
  });

  final String title;
  final List<TGroup> groups;
  final Map<TGroup, int> countByGroup;
  final String Function(TGroup) labelOf;
  final String Function(TGroup) descriptionOf;
  final ValueChanged<TGroup> onSelectGroup;
  final VoidCallback onClear;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;
    final countsByGroup = countByGroup;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MqSpacing.radiusXl),
        bottom: Radius.circular(MqSpacing.radiusXl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MqSpacing.space3,
          sigmaY: MqSpacing.space3,
        ),
        child: Container(
          // Matches the compact Food & Drink / Parking results panel (240)
          // instead of the previous 360, so these category lists no longer
          // dominate the map.
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: isDark
                ? MqColors.charcoal800.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MqSpacing.radiusXl),
              bottom: Radius.circular(MqSpacing.radiusXl),
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : MqColors.charcoal800.withValues(alpha: 0.06),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: MqColors.charcoal800.withValues(
                  alpha: isDark ? 0.30 : 0.10,
                ),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: MqSpacing.space3,
                ),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : MqColors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  MqSpacing.space4,
                  MqSpacing.space2,
                  MqSpacing.space2,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : MqColors.contentPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? Colors.white : MqColors.contentTertiary,
                      ),
                      tooltip: l10n.clear,
                      onPressed: onClear,
                    ),
                  ],
                ),
              ),

              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    MqSpacing.space2,
                    0,
                    MqSpacing.space2,
                    MqSpacing.space3,
                  ),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 0),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final count = countsByGroup[group] ?? 0;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsetsDirectional.symmetric(
                        horizontal: MqSpacing.space3,
                      ),
                      leading: Icon(leadingIcon, color: MqColors.red, size: 20),
                      title: Text(
                        labelOf(group),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : MqColors.contentPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${descriptionOf(group)}  ·  $count',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white : MqColors.charcoal600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: isDark ? Colors.white : MqColors.charcoal600,
                      ),
                      onTap: () => onSelectGroup(group),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterChips extends StatelessWidget {
  const _CategoryFilterChips({
    required this.activeQuery,
    required this.onSelect,
  });

  final String activeQuery;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final normalizedActive = activeQuery.trim().toLowerCase();

    final categories = <({IconData icon, String label, String query})>[
      (
        icon: Icons.support_agent,
        label: l10n.home_studentServices,
        query: 'student services',
      ),
      (icon: Icons.school, label: l10n.home_faculty, query: 'faculty'),
      (
        icon: Icons.account_balance,
        label: l10n.home_campusHub,
        query: 'campus hub',
      ),
      (icon: Icons.restaurant, label: l10n.home_foodDrink, query: 'food'),
      (icon: Icons.local_parking, label: l10n.home_parking, query: 'parking'),
    ];

    return SizedBox(
      height: MqSpacing.minTapTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.space2),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = normalizedActive == category.query;
          return _CategoryChip(
            icon: category.icon,
            label: category.label,
            isActive: isActive,
            isDark: isDark,
            onTap: () => onSelect(isActive ? '' : category.query),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeBg = MqColors.red;
    final inactiveBg = isDark
        ? MqColors.charcoal800.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.9);
    const activeFg = Colors.white;
    final inactiveFg = isDark ? Colors.white : MqColors.contentPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: isActive ? activeBg : inactiveBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
            side: BorderSide(
              color: isActive
                  ? activeBg
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : MqColors.charcoal800.withValues(alpha: 0.08)),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MqSpacing.space3,
                vertical: MqSpacing.space2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: isActive ? activeFg : inactiveFg),
                  const SizedBox(width: MqSpacing.space2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isActive ? activeFg : inactiveFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampusBuildingInfoPanel extends StatelessWidget {
  const _CampusBuildingInfoPanel({
    required this.selectedBuilding,
    required this.onClearSelection,
  });

  final Building selectedBuilding;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MqSpacing.radiusXl),
        bottom: Radius.circular(MqSpacing.radiusXl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MqSpacing.space3,
          sigmaY: MqSpacing.space3,
        ),
        child: Container(
          padding: const EdgeInsets.all(MqSpacing.space6),
          decoration: BoxDecoration(
            color: isDark
                ? MqColors.charcoal800.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MqSpacing.radiusXl),
              bottom: Radius.circular(MqSpacing.radiusXl),
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : MqColors.charcoal800.withValues(alpha: 0.06),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: MqColors.charcoal800.withValues(
                  alpha: isDark ? 0.30 : 0.10,
                ),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedBuilding.name,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : MqColors.contentPrimary,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: MqSpacing.space1),
                        Row(
                          children: [
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  text: '${l10n.buildingCode}: ',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.white
                                            : MqColors.contentTertiary,
                                      ),
                                  children: [
                                    TextSpan(
                                      text: selectedBuilding.code,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : MqColors.contentPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selectedBuilding.category !=
                                BuildingCategory.other) ...[
                              const SizedBox(width: MqSpacing.space2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: MqSpacing.space3,
                                  vertical: MqSpacing.space1,
                                ),
                                decoration: BoxDecoration(
                                  color: MqColors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    MqSpacing.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  selectedBuilding.category.name.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: MqColors.red,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: MqSpacing.iconMd,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : MqColors.contentTertiary,
                    ),
                    tooltip: l10n.clear,
                    onPressed: onClearSelection,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
