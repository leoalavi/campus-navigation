# Map Dependency Inventory

All map-related APIs, services, keys, and data sources used by the campus map subsystem.

## API Keys

| Key | Location | Usage | Flutter Approach |
|-----|----------|-------|-----------------|
| `ORS_API_KEY` (server, optional) | Supabase Edge Function secret | Campus walking route computation | Never exposed to Flutter |

## External Services

| Service | Web Usage | Flutter Usage |
|---------|-----------|---------------|
| OpenRouteService | Campus walking routing | `maps-routes` Supabase Edge Function |
| TfNSW Open Data | Transit timetable | `tfnsw-proxy` Supabase Edge Function |
| Raster campus overlay | Leaflet `L.CRS.Simple` image overlay | `flutter_map` + `OverlayImageLayer` + `CrsSimple` |

> **Note:** Campus mode now uses the exported web raster asset plus shared
> overlay metadata (`assets/data/campus_overlay_meta.json`), web-calibrated
> GPS projection coefficients, and pixel-space building coordinates exported
> from the web registry.

## Building Registry

- **Source**: `features/map/lib/buildings.ts` in web app (161 buildings in the current Flutter asset snapshot)
- **Fields per building**: id, code, name, description, tags, aliases, searchTokens, gridRef, address, category, latitude/longitude, entranceLatitude/entranceLongitude, levels, wheelchair, campusX/campusY
- **Categories**: academic, services, health, food, sports, venue, research, residential, other
- **Flutter storage**: Bundled JSON asset at `assets/data/buildings.json`
- **Overlay metadata**: `assets/data/campus_overlay_meta.json`
- **Overlay image**: `assets/maps/mq-campus.png`

## Map Configuration

| Config | Value | Notes |
|--------|-------|-------|
| Campus raster width | 4678 px | Shared with web `L.CRS.Simple` configuration |
| Campus raster height | 3307 px | Shared with web `L.CRS.Simple` configuration |
| Building pixel offset X | 80 px | Required for marker alignment with the raster |
| Campus fit padding | 20 px | Matches the web `fitBounds` padding |
| Campus min zoom offset | 1.5 | Flutter derives this from the fitted zoom like the web map |
| Campus max zoom | 4 | Image quality safe up to ~5; allows zoom-in on all screen sizes |
| Fallback location lat | -33.77388 | 18 Wally's Walk entrance — used when GPS unavailable |
| Fallback location lng | 151.11275 | 18 Wally's Walk entrance — used when GPS unavailable |
| GPS overlay projection | GCP affine regression | Shared with the web geospatial calibration |

## Flutter Map Packages

| Package | Version | Role |
|---------|---------|------|
| flutter_map | ^8.2.2 | Campus renderer foundation |
| latlong2 | ^0.9.1 | `flutter_map` geometry types |
| geolocator | ^14.0.2 | GPS location tracking |
| permission_handler | ^12.0.1 | Location permission flow |
| http | ^1.4.0 | Supabase Edge Function route requests |

## Map Features (Implemented)

| Feature | Package / Source |
|---------|-----------------|
| Building registry data source + bundled JSON asset | flutter assets |
| Current location tracking (fallback to campus centre on web/emulator) | geolocator + permission_handler |
| Campus map renderer | flutter_map + raster overlay image + `CrsSimple` |
| Building markers (selected + search result parity) | renderer-specific widgets |
| Building search bottom sheet | custom widget |
| Route request contract | repository + `maps-routes` remote source |
| Route polyline rendering | flutter_map |
| Travel mode switching (walk/drive/bike/transit) | shared `TravelMode` routed through `maps-routes` |
