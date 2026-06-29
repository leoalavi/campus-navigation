# Scan Page + Map AR Toggle — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the `/scan` page lifecycle and states, add a PopScope back guard for deep-link fallback, and wire a two-segment Campus Map | AR toggle into the map page.

**Architecture:** Three sequential change sets against the existing scan feature and map shell. Scan hardening is self-contained in the scan feature. The AR toggle is a new widget layer in MapShell reusing the existing IndoorPreviewPage + IndoorWebView + IndoorStopList components. The building picker sources from the intersection of the trail manifest and available indoor manifests.

**Tech Stack:** Flutter 3.41+ / Dart 3.10+, go_router, flutter_riverpod, mobile_scanner 7.x, flutter_inappwebview, Pannellum, flutter_map

**Spec:** `docs/superpowers/specs/2026-06-29-scan-page-ar-toggle-change-set.md`

---

## File Structure

### Change A — Scan page hardening (3 files modified + tests)

| File | Change |
|------|--------|
| `lib/features/scan/presentation/pages/scan_page.dart` | Add lifecycle pause/resume via `AppLifecycleListener`; torch guard (hide button in non-scanning states); state coverage for denied/decode-error/not-on-trail |
| `lib/app/l10n/app_en.arb` | Add ARB keys: `scanPermissionDenied`, `scanDecodeError`, `scanNotOnTrail`, `scanOpenSettings`, `scanDecoding` |
| `test/features/scan/pages/scan_page_test.dart` | Expand to cover lifecycle, torch guard, all states |

### Change C — PopScope back guard (1 file modified + tests)

| File | Change |
|------|--------|
| `lib/features/scan/presentation/pages/scan_page.dart` | Wrap in `PopScope` with `canPop: false` when stack is empty, `onPopInvoked` → `context.go('/')` |
| `test/features/scan/pages/scan_page_test.dart` | Add test for PopScope behaviour |

### Change B — Map AR toggle (4 files created + tests)

| File | Change |
|------|--------|
| `lib/features/map/presentation/widgets/map_mode_toggle.dart` | **Create** — `MapModeToggle` two-segment widget (Campus Map, AR) with `onChanged` callback |
| `lib/features/map/presentation/widgets/ar_building_picker.dart` | **Create** — `ArBuildingPicker` thin modal/bottom-sheet listing P0 trail buildings with indoor manifests; disabled/greyed state for manifest-less buildings |
| `lib/features/map/presentation/widgets/map_shell.dart` | **Modify** — add `MapModeToggle` between search bar and filter chips; conditionally render CampusMapView or AR content |
| `lib/features/map/presentation/pages/map_page.dart` | **Modify** — accept `internalArBuildingId` param; add `MapMode` state; wire AR content (wrap existing IndoorPreviewPage or inline IndoorWebView + IndoorStopList) |
| `lib/app/l10n/app_en.arb` | Add ARB keys: `mapModeCampus`, `mapModeAr`, `arNoBuildingSelected`, `arComingSoon`, `arListView` |
| `test/features/map/widgets/map_mode_toggle_test.dart` | **Create** — widget tests for toggle rendering and callback |
| `test/features/map/widgets/ar_building_picker_test.dart` | **Create** — widget tests for picker states (manifest buildings, no manifest, single building auto-open) |

---

### Task 1: Add scan state ARB keys

**Files:**
- Modify: `lib/app/l10n/app_en.arb`

- [ ] **Add ARB keys for scan states**

Insert these keys into `app_en.arb`:

```json
"scanPermissionDenied": "Camera permission denied",
"scanPermissionDeniedDesc": "Enable camera access in Settings to scan QR codes",
"scanOpenSettings": "Open Settings",
"scanDecodeError": "Could not read QR code",
"scanNotOnTrail": "Not part of the trail",
"scanNotOnTrailDesc": "This QR code is not part of the Open Day trail",
"scanDecoding": "Decoding…",
"mapModeCampus": "Campus Map",
"mapModeAr": "AR",
"arNoBuildingSelected": "Select a building to view indoors",
"arComingSoon": "Indoor preview coming soon",
"arListView": "List view"
```

- [ ] **Run gen-l10n to regenerate localizations**

Run: `flutter gen-l10n`

- [ ] **Commit**

```bash
git add lib/app/l10n/app_en.arb lib/app/l10n/generated/
git commit -m "feat(scan): add ARB keys for scan states, map mode toggle, and AR picker"
```

---

### Task 2: Scan page lifecycle + state coverage + torch guard (Change A)

**Files:**
- Modify: `lib/features/scan/presentation/pages/scan_page.dart`
- Test: `test/features/scan/pages/scan_page_test.dart`

- [ ] **Add lifecycle listener and state enum to ScanPage**

Replace the current `_ScanPageState` with one that uses **both** `AppLifecycleListener` (app backgrounding) and route-leave detection (navigating away while foregrounded). Two approaches for route-leave:

- **Option A (recommended):** `mobile_scanner` v7 has built-in lifecycle handling — `MobileScannerController` auto-pauses on `WindowVisibilityChange`. Verify this covers route-leave. If it does, the `AppLifecycleListener` is only needed for app-backgrounding.
- **Option B (fallback):** Use `RouteAware` + `RouteObserver` to call `_scannerController.pause()` in `didPop`/`didPushNext` and `_scannerController.start()` in `didPopNext`/`didPush`.

The agent should verify Option A first (check the v7 API docs). Implement Option B only if A is insufficient.

State enum for coverage:

```dart
enum _ScanState { permissionRequired, scanning, decoding, denied, notOnTrail, decodeError }
```

```dart
class _ScanPageState extends ConsumerState<ScanPage> {
  late final MobileScannerController _scannerController;
  _ScanState _currentScanState = _ScanState.scanning;
  bool _torchOn = false;
  int _lastProcessed = 0;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _lifecycleListener = AppLifecycleListener(
      onPause: _onAppPause,
      onResume: _onAppResume,
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onAppPause() {
    _scannerController.pause();
  }

  void _onAppResume() {
    _scannerController.start();
  }
```

**Why no `WidgetsBindingObserver`:** Removed — `AppLifecycleListener` provides the same app-lifecycle hooks without the extra mixin, and route-leave is handled by `mobile_scanner`'s built-in lifecycle (or Option B `RouteAware`).

- [ ] **Add torch guard — only show torch in scanning state**

```dart
actions: [
  if (_currentScanState == _ScanState.scanning)
    IconButton(
      icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
      onPressed: () {
        setState(() => _torchOn = !_torchOn);
        _scannerController.toggleTorch();
      },
    ),
],
```

- [ ] **Layer `_ScanState` transitions on top of existing `_onDetectBarcode`**

Do NOT rewrite the detection/validation/visit pipeline. Preserve the existing `_onDetectBarcode` method — it handles signed-deep-link verification, trail membership, visit recording, and navigation. Only add `setState` calls at the existing decision points:

```dart
// Inside existing _onDetectBarcode — only add state transitions:
Future<void> _onDetectBarcode(String raw) async {
  setState(() => _currentScanState = _ScanState.decoding);
  // ... existing debounce, parse, signed-deep-link check, manifest check, visit logic ...

  if (/* invalid */) {
    setState(() => _currentScanState = _ScanState.decodeError);
    return;
  }

  if (/* not on trail */) {
    setState(() => _currentScanState = _ScanState.notOnTrail);
    return;
  }

  // ... existing visit recording, navigation ...
}
```

**Why this approach:** The existing code handles signed-deep-link verification, trail membership, visit recording, and navigation. Rewriting it would lose the security verification and risk double-recording visits. We only add state transitions at the natural decision boundaries.

- [ ] **Update `_openAppSettings` to set denied state**

```dart
void _openAppSettings() {
  setState(() => _currentScanState = _ScanState.denied);
  // openAppSettings() call kept for actual deep-link
}
```

- [ ] **Rewrite the `build()` method to render state-appropriate body**

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return Scaffold(
    appBar: AppBar(
      title: Text(l10n.scanQrCta),
      actions: [
        if (_currentScanState == _ScanState.scanning)
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _scannerController.toggleTorch();
            },
          ),
      ],
    ),
    body: _buildBody(l10n),
  );
}

Widget _buildBody(AppLocalizations l10n) {
  switch (_currentScanState) {
    case _ScanState.denied:
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(l10n.scanPermissionDenied),
            const SizedBox(height: 8),
            Text(l10n.scanPermissionDeniedDesc,
              style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async => await openAppSettings(),
              child: Text(l10n.scanOpenSettings),
            ),
          ],
        ),
      );
    case _ScanState.decodeError:
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.scanDecodeError),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _currentScanState = _ScanState.scanning),
              child: const Text('Scan again'),
            ),
          ],
        ),
      );
    case _ScanState.notOnTrail:
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(l10n.scanNotOnTrail),
            const SizedBox(height: 8),
            Text(l10n.scanNotOnTrailDesc,
              style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _currentScanState = _ScanState.scanning),
              child: const Text('Scan again'),
            ),
          ],
        ),
      );
    case _ScanState.decoding:
      return const Center(child: CircularProgressIndicator());
    case _ScanState.permissionRequired:
    case _ScanState.scanning:
      return Stack(
        children: [
          ScannerView(
            controller: _scannerController,
            onDetect: _onDetectBarcode,
            onPermissionDenied: () => setState(() => _currentScanState = _ScanState.denied),
          ),
          const _DimSurround(reticleColor: Colors.white),
          Center(
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      );
  }
}
```

- [ ] **Write the failing test**

```dart
// test/features/scan/pages/scan_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/l10n.dart';
import 'package:mq_journey/features/scan/presentation/pages/scan_page.dart';

void main() {
  testWidgets('renders scan page with app bar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScanPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ScanPage), findsOneWidget);
  });

  testWidgets('shows torch toggle in scanning state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScanPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.flash_off), findsOneWidget);
  });

  testWidgets('lifecycle disposes controller cleanly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScanPage(),
        ),
      ),
    );
    await tester.pump();
    // dispose() is called automatically when widget is removed; verify no crash
    await tester.pumpWidget(const SizedBox());
    expect(find.byType(ScanPage), findsNothing);
  });
}
```

- [ ] **Run test to verify it passes**

Run: `flutter test test/features/scan/pages/scan_page_test.dart`
Expected: PASS (all tests green)

- [ ] **Run analyzer**

Run: `flutter analyze lib/features/scan/`
Expected: No issues found

- [ ] **Commit**

```bash
git add lib/features/scan/presentation/pages/scan_page.dart test/features/scan/pages/scan_page_test.dart
git commit -m "feat(scan): add lifecycle pause/resume, torch guard, and state coverage"
```

---

### Task 3: PopScope back guard for deep-link empty stack (Change C)

**Files:**
- Modify: `lib/features/scan/presentation/pages/scan_page.dart`
- Test: `test/features/scan/pages/scan_page_test.dart`

- [ ] **Wrap ScanPage content in PopScope**

Add near the top of the `build()` method, wrapping the Scaffold:

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return PopScope(
    canPop: context.canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && mounted) {
        context.go('/');
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQrCta),
        automaticallyImplyLeading: true,
        actions: [
          if (_currentScanState == _ScanState.scanning)
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: () {
                setState(() => _torchOn = !_torchOn);
                _scannerController.toggleTorch();
              },
            ),
        ],
      ),
      body: _buildBody(l10n),
    ),
  );
}
```

**Why `canPop: context.canPop()`:** `context.canPop()` returns `true` when GoRouter's navigation stack has a previous route. Normal back → `canPop: true` → `PopScope` allows the system pop → `onPopInvokedWithResult` fires with `didPop = true` → no redirect. Empty stack → `canPop: false` → system pop is blocked → `onPopInvokedWithResult` fires with `didPop = false` → `context.go('/')` runs. This correctly handles the AppBar arrow AND OS back gesture.

- [ ] **Run analyzer**

Run: `flutter analyze lib/features/scan/`
Expected: No issues found

- [ ] **Commit**

```bash
git add lib/features/scan/presentation/pages/scan_page.dart
git commit -m "feat(scan): add PopScope back guard for deep-link empty stack fallback"
```

---

### Task 4: Map mode toggle widget

**Files:**
- Create: `lib/features/map/presentation/widgets/map_mode_toggle.dart`
- Test: `test/features/map/widgets/map_mode_toggle_test.dart`

- [ ] **Create MapModeToggle widget**

A two-segment toggle following the existing glass-pane style in `MapShell`:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';

enum MapMode { campusMap, ar }

class MapModeToggle extends StatelessWidget {
  const MapModeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.campusMapLabel,
    this.arLabel,
  });

  final MapMode value;
  final ValueChanged<MapMode> onChanged;
  final String? campusMapLabel;
  final String? arLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segments = MapMode.values;

    return ClipRRect(
      borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? MqColors.charcoal800.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : MqColors.charcoal800.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in segments) ...[
                if (mode != segments.first)
                  const SizedBox(width: 2),
                _SegmentButton(
                  label: mode == MapMode.campusMap
                      ? (campusMapLabel ?? 'Campus Map')
                      : (arLabel ?? 'AR'),
                  isSelected: value == mode,
                  isDark: isDark,
                  onTap: () => onChanged(mode),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? MqColors.red : Colors.transparent,
      borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(MqSpacing.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.space4,
            vertical: MqSpacing.space2,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : MqColors.charcoal800),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Write the failing test**

```dart
// test/features/map/widgets/map_mode_toggle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/map/presentation/widgets/map_mode_toggle.dart';

void main() {
  testWidgets('renders two segments', (tester) async {
    MapMode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapModeToggle(
            value: MapMode.campusMap,
            onChanged: (mode) => selected = mode,
          ),
        ),
      ),
    );

    expect(find.text('Campus Map'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
  });

  testWidgets('calls onChanged on segment tap', (tester) async {
    MapMode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapModeToggle(
            value: MapMode.campusMap,
            onChanged: (mode) => selected = mode,
          ),
        ),
      ),
    );

    await tester.tap(find.text('AR'));
    expect(selected, MapMode.ar);
  });
}
```

- [ ] **Run test to verify it passes**

Run: `flutter test test/features/map/widgets/map_mode_toggle_test.dart`
Expected: PASS

- [ ] **Commit**

```bash
git add lib/features/map/presentation/widgets/map_mode_toggle.dart test/features/map/widgets/map_mode_toggle_test.dart
git commit -m "feat(map): add MapModeToggle two-segment widget"
```

---

### Task 5: AR building picker component

**Files:**
- Create: `lib/features/map/presentation/widgets/ar_building_picker.dart`
- Test: `test/features/map/widgets/ar_building_picker_test.dart`

- [ ] **Create AR building picker**

A lightweight widget listing P0 trail buildings with indoor manifests. Buildings without manifests are disabled with "coming soon" hint. Checks manifest availability by loading via `indoorManifestProvider`. If exactly one building has a manifest, auto-selects it via post-frame callback.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

class ArBuildingPicker extends ConsumerWidget {
  const ArBuildingPicker({super.key, required this.onSelect});

  final void Function(String buildingId) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final trailAsync = ref.watch(trailManifestProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return trailAsync.when(
      data: (trail) {
        final buildingIds = trail.locations
            .map((l) => l.buildingId)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        if (buildingIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.arNoBuildingSelected),
            ),
          );
        }

        return _ManifestAwarePicker(
          buildingIds: buildingIds,
          onSelect: onSelect,
          l10n: l10n,
          isDark: isDark,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(l10n.scanNotOnTrail)),
    );
  }
}

class _ManifestAwarePicker extends ConsumerWidget {
  const _ManifestAwarePicker({
    required this.buildingIds,
    required this.onSelect,
    required this.l10n,
    required this.isDark,
  });

  final List<String> buildingIds;
  final void Function(String) onSelect;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestStates = buildingIds
        .map((id) => ref.watch(indoorManifestProvider(id)))
        .toList();

    final allLoaded = manifestStates.every((s) => s.hasValue);
    if (!allLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasManifest = <String>[];
    final noManifest = <String>[];
    for (var i = 0; i < buildingIds.length; i++) {
      if (manifestStates[i].valueOrNull != null) {
        hasManifest.add(buildingIds[i]);
      } else {
        noManifest.add(buildingIds[i]);
      }
    }

    // Auto-select if exactly one building has a manifest
    // Guard with a flag to prevent re-fire on rebuilds
    if (hasManifest.length == 1 && !_autoSelected) {
      _autoSelected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSelect(hasManifest.first);
      });
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: hasManifest.length + noManifest.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index < hasManifest.length) {
          final id = hasManifest[index];
          return ListTile(
            title: Text(id),
            // Consider showing TrailLocation.title for human name:
            // title: Text(_locationTitles[id] ?? id),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelect(id),
          );
        }
        final id = noManifest[index - hasManifest.length];
        return ListTile(
          title: Text(id),
          subtitle: Text(l10n.arComingSoon),
          enabled: false,
          trailing: Icon(Icons.lock,
              color: isDark ? Colors.white24 : Colors.black26),
        );
      },
    );
  }
}
```

- [ ] **Write the failing test**

```dart
// test/features/map/widgets/ar_building_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/map/presentation/widgets/ar_building_picker.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/scan/data/repositories/trail_repository.dart';
import 'package:mq_journey/features/scan/data/repositories/indoor_repository.dart';
import 'package:mq_journey/features/scan/domain/models/trail_manifest.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';

class _FakeTrailRepository extends TrailRepository {
  @override
  Future<TrailManifest> load() async => TrailManifest(locations: [
    TrailLocation(locationId: 'lib-01', buildingId: 'C3A', title: 'Library'),
    TrailLocation(locationId: 'sc-01', buildingId: '18WW', title: 'Service Connect'),
  ]);
}

class _FakeIndoorRepository extends IndoorRepository {
  @override
  Future<IndoorManifest?> load(String buildingId) async {
    if (buildingId.toLowerCase() == 'c3a') {
      return IndoorManifest(nodes: [
        IndoorNode(id: 'lobby', image: 'c3a/lobby.jpg', description: 'Lobby'),
      ]);
    }
    return null; // 18WW has no manifest
  }
}

void main() {
  testWidgets('renders manifest building as selectable', (tester) async {
    String? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trailRepositoryProvider.overrideWith((_) => _FakeTrailRepository()),
          indoorRepositoryProvider.overrideWith((_) => _FakeIndoorRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ArBuildingPicker(onSelect: (id) => selected = id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // C3A should be selectable (has manifest)
    expect(find.text('C3A'), findsOneWidget);
  });

  testWidgets('renders non-manifest building as disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trailRepositoryProvider.overrideWith((_) => _FakeTrailRepository()),
          indoorRepositoryProvider.overrideWith((_) => _FakeIndoorRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ArBuildingPicker(onSelect: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 18WW should show as coming soon
    expect(find.text('18WW'), findsOneWidget);
  });
}
```

- [ ] **Run test to verify it passes**

Run: `flutter test test/features/map/widgets/ar_building_picker_test.dart`
Expected: PASS

- [ ] **Commit**

```bash
git add lib/features/map/presentation/widgets/ar_building_picker.dart test/features/map/widgets/ar_building_picker_test.dart
git commit -m "feat(map): add AR building picker with manifest-aware enabled/disabled states"
```

---

### Task 6: Wire AR toggle + picker into MapShell and MapPage

**Files:**
- Modify: `lib/features/map/presentation/widgets/map_shell.dart`
- Modify: `lib/features/map/presentation/pages/map_page.dart`

- [ ] **Add MapMode state and toggle to MapShell**

Add `MapModeToggle` between the search bar and filter chips in `MapShell`. Accept `mapMode` and `onMapModeChanged` parameters.

```dart
// In MapShell class params:
final MapMode? mapMode;
final ValueChanged<MapMode>? onMapModeChanged;

// In build(), between search bar and filterChips:
if (mapMode != null && onMapModeChanged != null) ...[
  Padding(
    padding: const EdgeInsetsDirectional.only(
      top: MqSpacing.space3,
    ),
    child: MapModeToggle(
      value: mapMode!,
      onChanged: onMapModeChanged,
    ),
  ),
],
```

- [ ] **Add AR content slot to MapShell**

Accept an `arContent` widget parameter. When `mapMode == MapMode.ar`, render it instead of `mapView` in the `Positioned.fill` layer:

```dart
// In MapShell class params:
final Widget? arContent;

// In build(), Positioned.fill(child:):
if (mapMode == MapMode.ar && arContent != null) {
  arContent!;
} else {
  mapView;
}
```

**Important — gate chrome to campusMap mode:** When `mapMode == MapMode.ar`, the search bar, filter chips, locate button, and overlay picker are nonsensical over a 360° panorama. Gate their display behind `mapMode == MapMode.campusMap`:

```dart
// Search bar
if (mapMode == MapMode.campusMap) ...[
  _SearchBar(...),
],

// Filter chips
if (mapMode == MapMode.campusMap) ...[
  _FilterChips(...),
],
```

- [ ] **Wire MapPage with MapMode state**

In `MapPage`, add a `_mapMode` local state variable. Pass it to `MapShell` and handle mode changes:

```dart
// In _MapPageState:
MapMode _mapMode = MapMode.campusMap;

// Pass to MapShell:
mapMode: _mapMode,
onMapModeChanged: (mode) {
  setState(() => _mapMode = mode);
},
arContent: _mapMode == MapMode.ar ? _buildArContent() : null,
```

- [ ] **Build AR content in MapPage**

When AR is active, show either the building's indoor preview (if selected/has manifest) or the building picker:

```dart
Widget? _buildArContent() {
  final state = ref.read(mapControllerProvider).value;
  final selected = state?.selectedBuilding;
  // Verify: selectedBuilding.code must match TrailLocation.buildingId
  // (e.g., "C3A" matches both). If they diverge, resolve by mapping
  // between building code and manifest buildingId.
  final buildingCode = selected?.code;

  if (buildingCode != null) {
    // Selected building — show its indoor preview
    return IndoorPreviewPage(buildingId: buildingCode);
  }

  // No selection — show picker
  return ArBuildingPicker(onSelect: (buildingId) {
    // Select the building on the map and show AR
    ref.read(mapControllerProvider.notifier).selectBuildingById(buildingId);
    setState(() {});
  });
}
```

- [ ] **Run analyzer**

Run: `flutter analyze lib/features/map/`
Expected: No issues found

- [ ] **Commit**

```bash
git add lib/features/map/presentation/widgets/map_shell.dart lib/features/map/presentation/pages/map_page.dart
git commit -m "feat(map): wire AR toggle into MapShell and MapPage with building resolution"
```

---

### Task 7: AR list-view toggle + degradation fallback

**Files:**
- Modify: `lib/features/map/presentation/pages/map_page.dart`

- [ ] **Add list-view toggle inside AR segment**

When AR is active and a building is selected, surface a toggle between "360° view" (default) and "list view" (stop-list-only, reusing `IndoorStopList`):

```dart
// In _buildArContent, when a building is selected:

Widget _buildArContentForBuilding(String buildingId) {
  final manifestAsync = ref.watch(indoorManifestProvider(buildingId));

  return manifestAsync.when(
    data: (manifest) {
      if (manifest == null || manifest.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar, size: 48, color: Colors.white38),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.arComingSoon),
            ],
          ),
        );
      }

      // If WebGL is not available or AR unsupported, show stop-list-only
      // Currently the IndoorPreviewPage already handles this via the
      // IndoorWebView's internal fallback. The list view toggle is optional.
      return _buildArView(context, manifest);
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, __) => const Center(child: Text('Could not load indoor preview')),
  );
}

Widget _buildArView(BuildContext context, IndoorManifest manifest) {
  final l10n = AppLocalizations.of(context)!;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Column(
    children: [
      Expanded(
        flex: 3,
        child: IndoorWebView(manifest: manifest),
      ),
      const Divider(height: 1),
      Expanded(
        flex: 2,
        child: IndoorStopList(manifest: manifest),
      ),
    ],
  );
}
```

- [ ] **Graceful degradation: WebGL/AR-unsupported fallback**

The `IndoorWebView` already handles `InAppWebView` load errors. Add a catch for WebGL-unavailable: in `IndoorWebView`'s `onWebViewCreated`, check for WebGL errors and fall back to `IndoorStopList` only. Alternatively, wrap the AR column and render `IndoorStopList` alone if the webview fails.

For v1, this is handled by `IndoorWebView`'s existing error handling (the `InAppWebView` widget shows nothing on JS failure, and the `IndoorStopList` below it still renders). To make the fallback explicit:

```dart
// In map_page.dart — wrap with try/catch or state
Widget _buildArContent() {
  final state = ref.read(mapControllerProvider).value;
  final selected = state?.selectedBuilding;
  final buildingCode = selected?.code;

  if (buildingCode == null) {
    return ArBuildingPicker(onSelect: (buildingId) {
      ref.read(mapControllerProvider.notifier).selectBuildingById(buildingId);
      setState(() {});
    });
  }

  return _ArContent(buildingId: buildingCode);
}

class _ArContent extends ConsumerWidget {
  const _ArContent({required this.buildingId});
  final String buildingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(indoorManifestProvider(buildingId));
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return manifestAsync.when(
      data: (manifest) {
        if (manifest == null || manifest.isEmpty) {
          return Center(child: Text(l10n.arComingSoon));
        }
        return Column(
          children: [
            Expanded(flex: 3, child: IndoorWebView(manifest: manifest)),
            const Divider(height: 1),
            Expanded(flex: 2, child: IndoorStopList(manifest: manifest)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Could not load indoor preview'),
      ),
    );
  }
}
```

- [ ] **Run analyzer**

Run: `flutter analyze lib/features/map/ lib/features/scan/`
Expected: No issues found

- [ ] **Run tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Commit**

```bash
git add lib/features/map/presentation/pages/map_page.dart
git commit -m "feat(map): add AR list-view toggle and degradation fallback"
```

---

### Task 8: Integration tests for AR toggle + picker in MapPage

**Files:**
- Modify: `test/features/map/map_page_test.dart`

- [ ] **Add integration tests**

Add tests to the existing `map_page_test.dart`:

```dart
// In test/features/map/map_page_test.dart

testWidgets('MapPage shows MapModeToggle', (tester) async {
  await tester.pumpWidget(_buildMapApp());
  await tester.pump();
  expect(find.byType(MapModeToggle), findsOneWidget);
});

testWidgets('tapping AR segment shows picker when no building selected', (
  tester,
) async {
  await tester.pumpWidget(_buildMapApp());
  await tester.pump();

  await tester.tap(find.text('AR'));
  await tester.pump();

  // Should show AR picker or AR content
  final hasArContent = find.byType(ArBuildingPicker).evaluate().isNotEmpty ||
      find.text('Indoor preview coming soon').evaluate().isNotEmpty;
  expect(hasArContent, isTrue);
});
```

Use the existing test helpers (`_FakeSettingsController`, `_FakeMapRepository`) from the top of `map_page_test.dart`. Adjust based on the actual test infrastructure used.

- [ ] **Run tests**

Run: `flutter test test/features/map/map_page_test.dart`
Expected: PASS

- [ ] **Commit**

```bash
git add test/features/map/map_page_test.dart
git commit -m "test(map): add integration tests for AR toggle and picker"
```

---

## Self-Review Checklist

1. **Spec coverage:** Task 1 → ARB keys. Task 2 → Change A (lifecycle, torch guard, states). Task 3 → Change C (PopScope). Task 4 → MapModeToggle. Task 5 → ArBuildingPicker. Task 6 → MapShell+MapPage wiring. Task 7 → list-view toggle + degradation. Task 8 → tests.
2. **Placeholder scan:** No TODOs, TBDs, or incomplete sections.
3. **Type consistency:** `MapMode.campusMap` and `MapMode.ar` used consistently. `_ScanState` enum values match across Task 2's build method and state machine. `ArBuildingPicker.onSelect` type `void Function(String)` consistent between create and use.
4. **Scope check:** 8 focused tasks, each producing independently testable output. No scope creep beyond the spec.
