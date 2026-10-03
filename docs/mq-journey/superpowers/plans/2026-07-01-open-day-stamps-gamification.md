# Open Day Stamps Celebration & Passport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a visitor's QR scan resolves to a confirmed first visit at one of the 9 canonical Open Day locations, show a congratulations celebration with the location's stamp, and let them browse a `/stamps` passport showing collected vs. locked stamps and overall progress.

**Architecture:** Reuse the existing scan → `ProgressApi.recordVisit` → local-write pipeline; amend its return type so the scan flow gets an exact `isNewVisit` signal instead of discarding it. Layer a new, Raouf-owned stamp catalogue (bundled JSON + model), a pure `computeStampAward` function that turns "isNewVisit + current visited set" into a `StampAward`, a modal `StampEarnedSheet` triggered inline from `ScanPage`, and a new `/stamps` grid page reachable from a Settings tile. No new backend calls beyond the existing `open_day_stamps` upsert; no XP/economy code is touched or introduced.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod ^3.3.2`), go_router `^17.3.0`, `confetti` (new dependency), existing `mobile_scanner`/`supabase_flutter` stack.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-01-open-day-stamps-gamification-design.md` — read before starting.
- Never import `lib/features/open_day/domain/services/open_day_gamification.dart` from any file created/modified in this plan (§3, §7 of the spec). Progress is always derived from `UserPreferences.visitedLocationCodes`.
- No XP number is ever rendered in celebration or passport UI.
- No new network calls beyond the existing `open_day_stamps` upsert (already implemented in `SettingsProgressApiAdapter._enqueueStampUpsert`).
- Motion (confetti) must be skipped when `MediaQuery.of(context).disableAnimations` is `true`; the congratulations message must still fire via `SemanticsService.sendAnnouncement` regardless of motion setting.
- All user-facing copy goes through ARB keys in `lib/app/l10n/app_en.arb` (camelCase keys); run `flutter gen-l10n` after editing ARB files.
- Follow existing MQ design tokens: `MqColors`, `MqSpacing` from `lib/app/theme/`; dark-mode awareness via `context.isDarkMode` (`lib/shared/extensions/context_extensions.dart`).
- **Deviation from spec §15 (documented, not a gap):** the `lottie` package is deferred — no Lottie stamp-reveal asset exists yet (same "asset not authored yet" situation already accepted for indoor panoramas per `CLAUDE.md` §5). The stamp reveal uses a lightweight built-in `TweenAnimationBuilder` scale/fade instead, gated by the same reduce-motion check. `confetti` is still added and used for real, since it needs no external asset. If real Lottie artwork is authored later, swapping the reveal widget is a follow-up, not a blocker.
- Stamp artwork (`assets/stamps/*.png`) does not exist yet either; all image usages must have an `errorBuilder` that falls back to a Material icon so the UI never crashes or renders blank on a missing asset — same pattern as the existing `PhotoGallery` fallback.
- **Deviation from spec §5 (documented, not a gap):** the spec sketches an abstract `StampCelebrationController` (`Stream<StampAward> awards`) as the trigger seam. This plan implements the equivalent behavior as a pure function (`computeStampAward`, Task 3) called directly and synchronously from `ScanPage._onDetectBarcode` right after `recordVisit` resolves (Task 7). A stream-based controller exists to guard against re-fires across widget rebuilds; that risk doesn't apply here because the trigger site is a single `await`ed call in an event handler, not a widget `build`/`watch`. This is simpler, fully covered by the same falsifiers (§10 of the spec: no double celebration, no re-fire on rebuild), and avoids an unused broadcast stream with no other subscriber.
- After all tasks are done, add matching entries to both `AGENT.md` and `CHANGELOG.md` per the project's Raouf change protocol (Task 12).

---

## Task 1: Amend `ProgressApi.recordVisit` to return `Future<bool>` (isNewVisit)

**Files:**
- Modify: `lib/features/scan/domain/contracts/progress_api.dart`
- Modify: `lib/features/scan/data/adapters/settings_progress_api_adapter.dart`
- Modify: `lib/features/scan/domain/fakes/fake_progress_api.dart`
- Modify: `lib/features/scan/presentation/pages/scan_page.dart:98` (capture the return value; not consumed yet — Task 7 wires it up)
- Test: `test/features/scan/adapters/settings_progress_api_adapter_test.dart`
- Test: `test/features/scan/fakes/fake_providers_test.dart`

**Interfaces:**
- Produces: `abstract class ProgressApi { Stream<VisitedState> watch(String locationId); Future<bool> recordVisit(VisitEvent event); }` — the `bool` is `true` only on a confirmed first visit. Tasks 3 and 7 depend on this signature.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/scan/adapters/settings_progress_api_adapter_test.dart`, replacing the existing `'recordVisit updates local state via settings controller'` test body and adding a new repeat-visit test:

```dart
    test('recordVisit returns true and updates local state on first visit', () async {
      final container = ProviderContainer(
        overrides: [
          progressApiProvider.overrideWith((ref) {
            return SettingsProgressApiAdapter(
              ref,
              supabaseClient: mockSupabaseClient,
            );
          }),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      final api = container.read(progressApiProvider);
      final event = VisitEvent(
        locationId: 'lib-01',
        buildingId: 'C3A',
        scannedAt: DateTime(2026, 6, 29, 10, 0),
      );

      final isNewVisit = await api.recordVisit(event);

      expect(isNewVisit, isTrue);
      final prefs = container.read(settingsControllerProvider).value;
      expect(prefs, isNotNull);
      expect(prefs!.visitedLocationCodes, contains('C3A'));
    });

    test('recordVisit returns false on a repeat visit to the same building', () async {
      final container = ProviderContainer(
        overrides: [
          progressApiProvider.overrideWith((ref) {
            return SettingsProgressApiAdapter(
              ref,
              supabaseClient: mockSupabaseClient,
            );
          }),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(),
          ),
        ],
      );
      addTearDown(() => container.dispose());

      final api = container.read(progressApiProvider);
      final event = VisitEvent(
        locationId: 'lib-01',
        buildingId: 'C3A',
        scannedAt: DateTime(2026, 6, 29, 10, 0),
      );

      final first = await api.recordVisit(event);
      final second = await api.recordVisit(event);

      expect(first, isTrue);
      expect(second, isFalse);
    });
```

Add to `test/features/scan/fakes/fake_providers_test.dart`, replacing the `'FakeProgressApi records visit and streams state'` test:

```dart
    test('FakeProgressApi returns true on first visit, false on repeat', () async {
      final api = FakeProgressApi();
      final event = VisitEvent(locationId: 'lib-01', scannedAt: DateTime.now());
      final first = await api.recordVisit(event);
      final second = await api.recordVisit(event);
      expect(first, isTrue);
      expect(second, isFalse);
      expect(api.watch('lib-01'), emits(isA<VisitedState>()));
      api.dispose();
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/scan/adapters/settings_progress_api_adapter_test.dart test/features/scan/fakes/fake_providers_test.dart`
Expected: FAIL — `recordVisit` currently returns `void`/`Future<void>`, so `final isNewVisit = await api.recordVisit(event);` fails to compile / type-check (`isNewVisit` would be `void`, and `expect(isNewVisit, isTrue)` fails analysis).

- [ ] **Step 3: Amend the contract and implementations**

`lib/features/scan/domain/contracts/progress_api.dart`:

```dart
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';

abstract class ProgressApi {
  Stream<VisitedState> watch(String locationId);

  /// Records a visit. Returns `true` only when this is a confirmed *new*
  /// visit (the location wasn't already recorded), so callers can trigger
  /// a celebration exactly once per location. Idempotent: repeat calls for
  /// an already-visited location return `false` and do not re-write.
  Future<bool> recordVisit(VisitEvent event);
}
```

`lib/features/scan/data/adapters/settings_progress_api_adapter.dart` — replace the `recordVisit` method:

```dart
  @override
  Future<bool> recordVisit(VisitEvent event) async {
    await ensureAnonSession(supabaseClient: _supabaseClient);
    var isNewVisit = false;
    if (event.buildingId != null) {
      isNewVisit = await _ref
          .read(settingsControllerProvider.notifier)
          .recordLocationVisit(event.buildingId!);
    }

    if (isNewVisit) {
      await _enqueueStampUpsert(event.locationId);
    }

    return isNewVisit;
  }
```

`lib/features/scan/domain/fakes/fake_progress_api.dart` — replace the `recordVisit` method:

```dart
  @override
  Future<bool> recordVisit(VisitEvent event) async {
    final isNewVisit = _visited.add(event.locationId);
    if (isNewVisit) {
      _controller.add(const VisitedState(visited: true, rewardEarned: false));
    }
    return isNewVisit;
  }
```

`lib/features/scan/presentation/pages/scan_page.dart:98` — capture the value (unused until Task 7):

```dart
    // ignore: unused_local_variable
    final isNewVisit = await ref.read(progressApiProvider).recordVisit(visit);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/scan/adapters/settings_progress_api_adapter_test.dart test/features/scan/fakes/fake_providers_test.dart`
Expected: PASS (5 tests in the adapter file, 3 in the fakes file)

- [ ] **Step 5: Run full analyze to catch any other callers**

Run: `flutter analyze`
Expected: 0 errors. (The `unused_local_variable` ignore in `scan_page.dart` prevents a new lint; Task 7 removes the ignore when the variable is actually used.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/scan/domain/contracts/progress_api.dart lib/features/scan/data/adapters/settings_progress_api_adapter.dart lib/features/scan/domain/fakes/fake_progress_api.dart lib/features/scan/presentation/pages/scan_page.dart test/features/scan/adapters/settings_progress_api_adapter_test.dart test/features/scan/fakes/fake_providers_test.dart
git commit -m "feat(scan): surface isNewVisit from ProgressApi.recordVisit"
```

---

## Task 2: Stamp catalogue — model, bundled JSON, repository, providers

**Files:**
- Create: `lib/features/scan/domain/contracts/stamp_catalog_entry.dart`
- Create: `assets/data/open_day_stamps_catalog.json`
- Create: `lib/features/scan/data/repositories/stamp_catalog_repository.dart`
- Modify: `lib/features/scan/providers/scan_providers.dart`
- Modify: `pubspec.yaml` (assets already cover `assets/data/` non-recursively — this file lives directly in `assets/data/`, so no new asset line needed; `assets/stamps/` does need its own line, added in Task 10)
- Test: `test/features/scan/repositories/stamp_catalog_repository_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `class StampCatalogEntry { final String locationId, title, mapRef, stampAsset; }`, `class StampCatalogRepository { Future<List<StampCatalogEntry>> load(); }`, `final stampCatalogProvider = FutureProvider<List<StampCatalogEntry>>(...)`. Tasks 3, 6, 7, 8 depend on `StampCatalogEntry` and `stampCatalogProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/features/scan/repositories/stamp_catalog_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/data/repositories/stamp_catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads all 9 canonical stamp catalogue entries from the bundled asset', () async {
    final repository = StampCatalogRepository();
    final entries = await repository.load();

    expect(entries.length, 9);
    expect(entries.map((e) => e.locationId), contains('wallys-1'));
    final wallys1 = entries.firstWhere((e) => e.locationId == 'wallys-1');
    expect(wallys1.title, "1 Wally's Walk");
    expect(wallys1.mapRef, 'K27');
    expect(wallys1.stampAsset, 'assets/stamps/wallys-1.png');
  });

  test('caches the result after the first load', () async {
    final repository = StampCatalogRepository();
    final first = await repository.load();
    final second = await repository.load();
    expect(identical(first, second), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/scan/repositories/stamp_catalog_repository_test.dart`
Expected: FAIL — `stamp_catalog_repository.dart` doesn't exist yet (import error).

- [ ] **Step 3: Create the model, asset, and repository**

`lib/features/scan/domain/contracts/stamp_catalog_entry.dart`:

```dart
import 'package:flutter/foundation.dart';

@immutable
class StampCatalogEntry {
  final String locationId;
  final String title;
  final String mapRef;
  final String stampAsset;

  const StampCatalogEntry({
    required this.locationId,
    required this.title,
    required this.mapRef,
    required this.stampAsset,
  });

  factory StampCatalogEntry.fromJson(Map<String, dynamic> json) {
    return StampCatalogEntry(
      locationId: json['locationId'] as String,
      title: json['title'] as String,
      mapRef: json['mapRef'] as String,
      stampAsset: json['stampAsset'] as String,
    );
  }
}
```

`assets/data/open_day_stamps_catalog.json`:

```json
{ "stamps": [
  { "locationId": "hadenfeld-10", "title": "10 Hadenfeld Avenue",            "mapRef": "P6",  "stampAsset": "assets/stamps/hadenfeld-10.png" },
  { "locationId": "wallys-29",    "title": "29 Wally's Walk",                "mapRef": "L11", "stampAsset": "assets/stamps/wallys-29.png" },
  { "locationId": "wallys-27",    "title": "27 Wally's Walk",                "mapRef": "L12", "stampAsset": "assets/stamps/wallys-27.png" },
  { "locationId": "wallys-23",    "title": "23 Wally's Walk",                "mapRef": "L14", "stampAsset": "assets/stamps/wallys-23.png" },
  { "locationId": "wallys-21",    "title": "21 Wally's Walk",                "mapRef": "L15", "stampAsset": "assets/stamps/wallys-21.png" },
  { "locationId": "wallys-17",    "title": "17 Wally's Walk",                "mapRef": "L17", "stampAsset": "assets/stamps/wallys-17.png" },
  { "locationId": "ondaatje-14",  "title": "14 Sir Christopher Ondaatje Ave", "mapRef": "J20", "stampAsset": "assets/stamps/ondaatje-14.png" },
  { "locationId": "wallys-1",     "title": "1 Wally's Walk",                 "mapRef": "K27", "stampAsset": "assets/stamps/wallys-1.png" },
  { "locationId": "wallys-25",    "title": "25 Wally's Walk",                "mapRef": "N12", "stampAsset": "assets/stamps/wallys-25.png" }
] }
```

`lib/features/scan/data/repositories/stamp_catalog_repository.dart`:

```dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';

class StampCatalogRepository {
  List<StampCatalogEntry>? _cached;

  Future<List<StampCatalogEntry>> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString(
      'assets/data/open_day_stamps_catalog.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final stamps = json['stamps'] as List<dynamic>;
    _cached = stamps
        .map((e) => StampCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cached!;
  }
}
```

Append to `lib/features/scan/providers/scan_providers.dart` (add import + two providers at the end of the file):

```dart
import 'package:mq_journey/features/scan/data/repositories/stamp_catalog_repository.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
```

```dart
final stampCatalogRepositoryProvider = Provider<StampCatalogRepository>(
  (ref) => StampCatalogRepository(),
);

final stampCatalogProvider = FutureProvider<List<StampCatalogEntry>>((ref) {
  return ref.watch(stampCatalogRepositoryProvider).load();
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/scan/repositories/stamp_catalog_repository_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/scan/domain/contracts/stamp_catalog_entry.dart assets/data/open_day_stamps_catalog.json lib/features/scan/data/repositories/stamp_catalog_repository.dart lib/features/scan/providers/scan_providers.dart test/features/scan/repositories/stamp_catalog_repository_test.dart
git commit -m "feat(scan): add bundled stamp catalogue (9 canonical locations)"
```

---

## Task 3: `computeStampAward` — pure derivation of the celebration payload

**Files:**
- Create: `lib/features/scan/domain/services/stamp_award_calculator.dart`
- Test: `test/features/scan/services/stamp_award_calculator_test.dart`

**Interfaces:**
- Consumes: `StampCatalogEntry` (Task 2).
- Produces: `class StampAward { final StampCatalogEntry stamp; final int collectedCount; final int total; final bool isFirst; final bool isComplete; }` and `StampAward? computeStampAward({required String visitedCode, required List<String> visitedLocationCodesAfterVisit, required List<StampCatalogEntry> catalog})`. Tasks 6, 7, 8 depend on this exact signature.

- [ ] **Step 1: Write the failing test**

Create `test/features/scan/services/stamp_award_calculator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';

void main() {
  const catalog = [
    StampCatalogEntry(
      locationId: 'wallys-1',
      title: "1 Wally's Walk",
      mapRef: 'K27',
      stampAsset: 'assets/stamps/wallys-1.png',
    ),
    StampCatalogEntry(
      locationId: 'wallys-25',
      title: '25 Wally\'s Walk',
      mapRef: 'N12',
      stampAsset: 'assets/stamps/wallys-25.png',
    ),
  ];

  test('returns null when the visited code is not in the catalogue', () {
    final award = computeStampAward(
      visitedCode: 'not-a-stamp-location',
      visitedLocationCodesAfterVisit: const ['NOT-A-STAMP-LOCATION'],
      catalog: catalog,
    );
    expect(award, isNull);
  });

  test('marks the first collected stamp as isFirst and not isComplete', () {
    final award = computeStampAward(
      visitedCode: 'wallys-1',
      visitedLocationCodesAfterVisit: const ['WALLYS-1'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.stamp.locationId, 'wallys-1');
    expect(award.collectedCount, 1);
    expect(award.total, 2);
    expect(award.isFirst, isTrue);
    expect(award.isComplete, isFalse);
  });

  test('marks the final stamp as isComplete and not isFirst', () {
    final award = computeStampAward(
      visitedCode: 'wallys-25',
      visitedLocationCodesAfterVisit: const ['WALLYS-1', 'WALLYS-25'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.collectedCount, 2);
    expect(award.isFirst, isFalse);
    expect(award.isComplete, isTrue);
  });

  test('matching is case-insensitive between catalogue and visited codes', () {
    final award = computeStampAward(
      visitedCode: 'WALLYS-1',
      visitedLocationCodesAfterVisit: const ['wallys-1'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.collectedCount, 1);
  });

  test('ignores visited codes that are not part of the catalogue', () {
    final award = computeStampAward(
      visitedCode: 'wallys-1',
      visitedLocationCodesAfterVisit: const ['WALLYS-1', 'SOME-OTHER-BUILDING'],
      catalog: catalog,
    );
    expect(award, isNotNull);
    expect(award!.collectedCount, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/scan/services/stamp_award_calculator_test.dart`
Expected: FAIL — `stamp_award_calculator.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

Create `lib/features/scan/domain/services/stamp_award_calculator.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';

@immutable
class StampAward {
  final StampCatalogEntry stamp;
  final int collectedCount;
  final int total;
  final bool isFirst;
  final bool isComplete;

  const StampAward({
    required this.stamp,
    required this.collectedCount,
    required this.total,
    required this.isFirst,
    required this.isComplete,
  });
}

/// Computes the stamp award for a confirmed visit, or `null` when the
/// visited location isn't one of the catalogued Open Day stamp locations.
///
/// [visitedLocationCodesAfterVisit] must be read AFTER the local write
/// completes (it should already include this visit's code) and may use
/// any casing — comparison is case-insensitive to bridge
/// `UserPreferences.visitedLocationCodes` (stored upper-case) against
/// `StampCatalogEntry.locationId` (stored lower-case, e.g. "wallys-1").
StampAward? computeStampAward({
  required String visitedCode,
  required List<String> visitedLocationCodesAfterVisit,
  required List<StampCatalogEntry> catalog,
}) {
  final normalizedVisitedCode = visitedCode.trim().toUpperCase();
  StampCatalogEntry? entry;
  for (final candidate in catalog) {
    if (candidate.locationId.toUpperCase() == normalizedVisitedCode) {
      entry = candidate;
      break;
    }
  }
  if (entry == null) return null;

  final catalogIds = {for (final c in catalog) c.locationId.toUpperCase()};
  final collected = <String>{
    for (final code in visitedLocationCodesAfterVisit)
      if (catalogIds.contains(code.trim().toUpperCase()))
        code.trim().toUpperCase(),
  };

  final collectedCount = collected.length;
  return StampAward(
    stamp: entry,
    collectedCount: collectedCount,
    total: catalog.length,
    isFirst: collectedCount == 1,
    isComplete: collectedCount == catalog.length,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/scan/services/stamp_award_calculator_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/scan/domain/services/stamp_award_calculator.dart test/features/scan/services/stamp_award_calculator_test.dart
git commit -m "feat(scan): add pure computeStampAward derivation"
```

---

## Task 4: Localisation keys for celebration, passport, and Settings tile copy

**Files:**
- Modify: `lib/app/l10n/app_en.arb`

**Interfaces:**
- Produces: `AppLocalizations` getters — `stampCelebrationTitle`, `stampCelebrationCompleteTitle`, `stampCelebrationSubtitle(String location)`, `stampCelebrationFirstNote`, `stampCelebrationKeepExploring`, `stampCelebrationViewPassport`, `stampAlreadyCollected(String location)`, `stampAnnouncementCongrats(String location, int count, int total)`, `stampsPassportTitle`, `stampsPassportLockedHint`, `settingsMyStampsTile`, `settingsMyStampsSubtitle`. Tasks 6, 7, 8, 9 depend on these getters existing on `AppLocalizations`.

- [ ] **Step 1: Add the ARB entries**

Append to `lib/app/l10n/app_en.arb` (before the final closing `}` of the file; keep valid JSON — add a comma after the previous last entry):

```json
  "stampCelebrationTitle": "Congratulations!",
  "stampCelebrationCompleteTitle": "Passport complete!",
  "stampCelebrationSubtitle": "You collected the {location} stamp",
  "@stampCelebrationSubtitle": {
    "placeholders": {
      "location": {
        "type": "String"
      }
    }
  },
  "stampCelebrationFirstNote": "Your Open Day passport has begun",
  "stampCelebrationKeepExploring": "Keep exploring",
  "stampCelebrationViewPassport": "View my passport",
  "stampAlreadyCollected": "Already collected — {location}",
  "@stampAlreadyCollected": {
    "placeholders": {
      "location": {
        "type": "String"
      }
    }
  },
  "stampAnnouncementCongrats": "Congratulations. You collected the {location} stamp. {count} of {total}.",
  "@stampAnnouncementCongrats": {
    "placeholders": {
      "location": {
        "type": "String"
      },
      "count": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "stampsPassportTitle": "My Stamps",
  "stampsPassportLockedHint": "Scan to collect",
  "settingsMyStampsTile": "My Stamps",
  "settingsMyStampsSubtitle": "View your Open Day passport"
```

- [ ] **Step 2: Regenerate localisations**

Run: `flutter gen-l10n`
Expected: succeeds with no errors; `lib/app/l10n/generated/app_localizations_en.dart` (and the base `app_localizations.dart`) now declare the new getters. Untranslated keys in the other 34 locale ARB files are tolerated by CI (per `CLAUDE.md` §2).

- [ ] **Step 3: Verify the getters compile**

Run: `flutter analyze lib/app/l10n`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/app/l10n/app_en.arb lib/app/l10n/generated/
git commit -m "i18n(scan): add ARB keys for stamp celebration/passport copy"
```

---

## Task 5: `StampProgressRing` shared widget

**Files:**
- Create: `lib/features/scan/presentation/widgets/stamp_progress_ring.dart`
- Test: `test/features/scan/widgets/stamp_progress_ring_test.dart`

**Interfaces:**
- Produces: `class StampProgressRing extends StatelessWidget { const StampProgressRing({super.key, required int collected, required int total, double size = 64}); }`. Tasks 6 and 8 depend on this constructor.

- [ ] **Step 1: Write the failing test**

Create `test/features/scan/widgets/stamp_progress_ring_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_progress_ring.dart';

void main() {
  testWidgets('renders the collected/total count as text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StampProgressRing(collected: 3, total: 9),
        ),
      ),
    );

    expect(find.text('3/9'), findsOneWidget);
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(3 / 9, 0.0001));
  });

  testWidgets('clamps progress to 1.0 when collected exceeds total', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StampProgressRing(collected: 9, total: 9),
        ),
      ),
    );

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/scan/widgets/stamp_progress_ring_test.dart`
Expected: FAIL — widget file doesn't exist yet.

- [ ] **Step 3: Implement**

Create `lib/features/scan/presentation/widgets/stamp_progress_ring.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';

class StampProgressRing extends StatelessWidget {
  const StampProgressRing({
    super.key,
    required this.collected,
    required this.total,
    this.size = 64,
  });

  final int collected;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (collected / total).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: MqColors.charcoal800.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(MqColors.red),
            ),
          ),
          Text(
            '$collected/$total',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/scan/widgets/stamp_progress_ring_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/scan/presentation/widgets/stamp_progress_ring.dart test/features/scan/widgets/stamp_progress_ring_test.dart
git commit -m "feat(scan): add StampProgressRing shared widget"
```

---

## Task 6: `StampEarnedSheet` celebration widget + `showStampEarnedSheet` helper

**Files:**
- Create: `lib/features/scan/presentation/widgets/stamp_earned_sheet.dart`
- Modify: `pubspec.yaml` (add `confetti: ^0.8.0`)
- Test: `test/features/scan/widgets/stamp_earned_sheet_test.dart`

**Interfaces:**
- Consumes: `StampAward` (Task 3), `StampProgressRing` (Task 5), ARB getters (Task 4).
- Produces: `enum StampSheetAction { viewPassport, keepExploring }` and `Future<StampSheetAction?> showStampEarnedSheet(BuildContext context, StampAward award)`. Task 7 depends on this exact function signature and enum.

- [ ] **Step 1: Add the dependency**

Add to `pubspec.yaml` under the `# UI` section:

```yaml
  confetti: ^0.8.0
```

Run: `flutter pub get`
Expected: resolves successfully.

- [ ] **Step 2: Write the failing test**

Create `test/features/scan/widgets/stamp_earned_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';

const _award = StampAward(
  stamp: StampCatalogEntry(
    locationId: 'wallys-1',
    title: "1 Wally's Walk",
    mapRef: 'K27',
    stampAsset: 'assets/stamps/wallys-1.png',
  ),
  collectedCount: 1,
  total: 9,
  isFirst: true,
  isComplete: false,
);

Widget _app(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('shows the stamp title, first-visit note, and progress', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showStampEarnedSheet(context, _award),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StampEarnedSheet)),
    )!;
    expect(find.text(l10n.stampCelebrationTitle), findsOneWidget);
    expect(
      find.text(l10n.stampCelebrationSubtitle(_award.stamp.title)),
      findsOneWidget,
    );
    expect(find.text(l10n.stampCelebrationFirstNote), findsOneWidget);
    expect(find.text('1/9'), findsOneWidget);
  });

  testWidgets('View my passport CTA returns StampSheetAction.viewPassport', (tester) async {
    StampSheetAction? result;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStampEarnedSheet(context, _award);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(StampEarnedSheet)),
    )!;
    await tester.tap(find.text(l10n.stampCelebrationViewPassport));
    await tester.pumpAndSettle();

    expect(result, StampSheetAction.viewPassport);
  });

  testWidgets('reduce-motion skips confetti but still renders content', (tester) async {
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showStampEarnedSheet(context, _award),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(StampEarnedSheet), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/scan/widgets/stamp_earned_sheet_test.dart`
Expected: FAIL — `stamp_earned_sheet.dart` doesn't exist yet.

- [ ] **Step 4: Implement**

Create `lib/features/scan/presentation/widgets/stamp_earned_sheet.dart`:

```dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_progress_ring.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/mq_bottom_sheet.dart';

enum StampSheetAction { viewPassport, keepExploring }

/// Shows the stamp-earned celebration sheet and returns the action the user
/// picked, or `null` if dismissed by tapping outside/back (callers should
/// treat `null` the same as [StampSheetAction.keepExploring]).
Future<StampSheetAction?> showStampEarnedSheet(
  BuildContext context,
  StampAward award,
) {
  final l10n = AppLocalizations.of(context)!;
  SemanticsService.sendAnnouncement(
    l10n.stampAnnouncementCongrats(
      award.stamp.title,
      award.collectedCount,
      award.total,
    ),
    Directionality.of(context),
  );
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  return showModalBottomSheet<StampSheetAction>(
    context: context,
    isScrollControlled: true,
    builder: (_) => StampEarnedSheet(award: award, playEffects: !reduceMotion),
  );
}

class StampEarnedSheet extends StatefulWidget {
  const StampEarnedSheet({
    super.key,
    required this.award,
    required this.playEffects,
  });

  final StampAward award;
  final bool playEffects;

  @override
  State<StampEarnedSheet> createState() => _StampEarnedSheetState();
}

class _StampEarnedSheetState extends State<StampEarnedSheet> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 700),
    );
    if (widget.playEffects) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final award = widget.award;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        MqBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: widget.playEffects ? 0.6 : 1.0,
                    end: 1.0,
                  ),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Image.asset(
                    award.stamp.stampAsset,
                    width: 96,
                    height: 96,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.local_activity_outlined,
                      size: 96,
                      color: MqColors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MqSpacing.space4),
              Text(
                award.isComplete
                    ? l10n.stampCelebrationCompleteTitle
                    : l10n.stampCelebrationTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : MqColors.contentPrimary,
                ),
              ),
              const SizedBox(height: MqSpacing.space2),
              Text(
                l10n.stampCelebrationSubtitle(award.stamp.title),
                textAlign: TextAlign.center,
              ),
              if (award.isFirst) ...[
                const SizedBox(height: MqSpacing.space2),
                Text(
                  l10n.stampCelebrationFirstNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: MqSpacing.space4),
              StampProgressRing(
                collected: award.collectedCount,
                total: award.total,
              ),
              const SizedBox(height: MqSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        StampSheetAction.keepExploring,
                      ),
                      child: Text(l10n.stampCelebrationKeepExploring),
                    ),
                  ),
                  const SizedBox(width: MqSpacing.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        StampSheetAction.viewPassport,
                      ),
                      child: Text(l10n.stampCelebrationViewPassport),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.playEffects)
          ExcludeSemantics(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 24,
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/scan/widgets/stamp_earned_sheet_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/scan/presentation/widgets/stamp_earned_sheet.dart test/features/scan/widgets/stamp_earned_sheet_test.dart
git commit -m "feat(scan): add StampEarnedSheet celebration with confetti + reduce-motion gating"
```

---

## Task 7: Wire `ScanPage` to trigger the celebration / subdued re-scan acknowledgment

**Files:**
- Modify: `lib/features/scan/presentation/pages/scan_page.dart`
- Modify: `test/features/scan/pages/scan_page_test.dart`

**Interfaces:**
- Consumes: `progressApiProvider.recordVisit` (Task 1), `stampCatalogProvider` (Task 2), `computeStampAward` (Task 3), `showStampEarnedSheet`/`StampSheetAction` (Task 6), `settingsControllerProvider` (existing).

- [ ] **Step 1: Write the failing test**

Add to `test/features/scan/pages/scan_page_test.dart` (new imports + new test at the end of `main()`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/domain/fakes/fake_progress_api.dart';
import 'package:mq_journey/features/scan/presentation/widgets/scanner_view.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
```

```dart
  testWidgets(
    'first scan of a catalogued location shows the celebration sheet',
    (tester) async {
      final progressApi = FakeProgressApi();
      addTearDown(progressApi.dispose);

      final router = GoRouter(
        initialLocation: '/scan',
        routes: [
          GoRoute(path: '/scan', builder: (_, _) => const ScanPage()),
          GoRoute(
            path: '/location/:locationId',
            builder: (_, s) => Scaffold(
              body: Text('location-${s.pathParameters['locationId']}'),
            ),
          ),
          GoRoute(
            path: '/stamps',
            builder: (_, _) => const Scaffold(body: Text('stamps-page')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressApiProvider.overrideWithValue(progressApi),
            stampCatalogProvider.overrideWith(
              (ref) async => const [
                StampCatalogEntry(
                  locationId: 'wallys-1',
                  title: "1 Wally's Walk",
                  mapRef: 'K27',
                  stampAsset: 'assets/stamps/wallys-1.png',
                ),
              ],
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      final scannerView = tester.widget<ScannerView>(find.byType(ScannerView));
      scannerView.onDetect(
        'https://mq.edu.au/scan?locationId=wallys-1',
      );
      await tester.pumpAndSettle();

      expect(find.byType(StampEarnedSheet), findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(StampEarnedSheet)),
      )!;
      await tester.tap(find.text(l10n.stampCelebrationKeepExploring));
      await tester.pumpAndSettle();

      expect(find.text('location-wallys-1'), findsOneWidget);
    },
  );

  testWidgets('re-scanning an already-collected location skips the sheet', (
    tester,
  ) async {
    final progressApi = FakeProgressApi();
    addTearDown(progressApi.dispose);
    // Pre-seed the visit so the second scan is a repeat.
    await progressApi.recordVisit(
      VisitEvent(locationId: 'wallys-1', scannedAt: DateTime.now()),
    );

    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(path: '/scan', builder: (_, _) => const ScanPage()),
        GoRoute(
          path: '/location/:locationId',
          builder: (_, s) => Scaffold(
            body: Text('location-${s.pathParameters['locationId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressApiProvider.overrideWithValue(progressApi),
          stampCatalogProvider.overrideWith(
            (ref) async => const [
              StampCatalogEntry(
                locationId: 'wallys-1',
                title: "1 Wally's Walk",
                mapRef: 'K27',
                stampAsset: 'assets/stamps/wallys-1.png',
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    final scannerView = tester.widget<ScannerView>(find.byType(ScannerView));
    scannerView.onDetect('https://mq.edu.au/scan?locationId=wallys-1');
    await tester.pumpAndSettle();

    expect(find.byType(StampEarnedSheet), findsNothing);
    expect(find.text('location-wallys-1'), findsOneWidget);
  });
```

Note: `VisitEvent` is already imported by `scan_page_test.dart`'s subject under test transitively — add `import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';` explicitly to the test file's import list if not already present.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/scan/pages/scan_page_test.dart`
Expected: FAIL — `ScanPage` doesn't yet look up the catalogue or show `StampEarnedSheet`, so `find.byType(StampEarnedSheet)` finds nothing in the first test.

- [ ] **Step 3: Wire the celebration into `ScanPage`**

In `lib/features/scan/presentation/pages/scan_page.dart`, add imports:

```dart
import 'package:mq_journey/features/scan/domain/services/stamp_award_calculator.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_earned_sheet.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
```

Replace the tail of `_onDetectBarcode` (from the `VisitEvent` construction to the end of the method):

```dart
    final visit = VisitEvent(
      locationId: locationId,
      buildingId: location.buildingId,
      scannedAt: DateTime.now(),
    );
    final isNewVisit = await ref.read(progressApiProvider).recordVisit(visit);

    final visitedCode = visit.buildingId ?? visit.locationId;
    final catalog = await ref.read(stampCatalogProvider.future);
    final visitedCodesAfter =
        ref.read(settingsControllerProvider).value?.visitedLocationCodes ??
        const <String>[];
    final award = computeStampAward(
      visitedCode: visitedCode,
      visitedLocationCodesAfterVisit: visitedCodesAfter,
      catalog: catalog,
    );

    if (!mounted) return;

    if (award != null) {
      if (isNewVisit) {
        final action = await showStampEarnedSheet(context, award);
        if (action == StampSheetAction.viewPassport) {
          if (!mounted) return;
          context.push('/stamps');
          return;
        }
      } else {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.stampAlreadyCollected(award.stamp.title))),
        );
      }
    }

    if (!mounted) return;
    context.go('/location/$locationId');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/scan/pages/scan_page_test.dart`
Expected: PASS (5 tests: the original 3 plus the 2 new ones)

- [ ] **Step 5: Run the full scan feature suite + analyze**

Run: `flutter analyze && flutter test test/features/scan/`
Expected: 0 analyze issues; all scan tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/scan/presentation/pages/scan_page.dart test/features/scan/pages/scan_page_test.dart
git commit -m "feat(scan): trigger stamp celebration on confirmed first visit, subdued ack on re-scan"
```

---

## Task 8: `/stamps` route and `StampsPassportPage`

**Files:**
- Modify: `lib/app/router/route_names.dart`
- Modify: `lib/app/router/app_router.dart`
- Create: `lib/features/scan/presentation/pages/stamps_passport_page.dart`
- Test: `test/features/scan/pages/stamps_passport_page_test.dart`

**Interfaces:**
- Consumes: `stampCatalogProvider` (Task 2), `StampProgressRing` (Task 5), `settingsControllerProvider` (existing).
- Produces: `RouteNames.stamps`, `class StampsPassportPage extends ConsumerWidget`. Task 9 depends on `RouteNames.stamps` and the route being pushable via `context.pushNamed(RouteNames.stamps)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/scan/pages/stamps_passport_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/presentation/pages/stamps_passport_page.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

const _catalog = [
  StampCatalogEntry(
    locationId: 'wallys-1',
    title: "1 Wally's Walk",
    mapRef: 'K27',
    stampAsset: 'assets/stamps/wallys-1.png',
  ),
  StampCatalogEntry(
    locationId: 'wallys-25',
    title: "25 Wally's Walk",
    mapRef: 'N12',
    stampAsset: 'assets/stamps/wallys-25.png',
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  Widget buildApp(MockSettingsRepository mockRepo) {
    final router = GoRouter(
      initialLocation: '/stamps',
      routes: [
        GoRoute(path: '/stamps', builder: (_, _) => const StampsPassportPage()),
        GoRoute(
          path: '/location/:locationId',
          builder: (_, s) => Scaffold(
            body: Text('location-${s.pathParameters['locationId']}'),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(mockRepo),
        stampCatalogProvider.overrideWith((ref) async => _catalog),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('shows collected and locked cells with correct progress ring', (
    tester,
  ) async {
    final mockRepo = MockSettingsRepository();
    when(() => mockRepo.loadPreferences()).thenAnswer(
      (_) async => const UserPreferences(visitedLocationCodes: ['WALLYS-1']),
    );

    await tester.pumpWidget(buildApp(mockRepo));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text("1 Wally's Walk"), findsOneWidget);
    expect(find.text("25 Wally's Walk"), findsOneWidget);
  });

  testWidgets('tapping a collected stamp opens its location card', (tester) async {
    final mockRepo = MockSettingsRepository();
    when(() => mockRepo.loadPreferences()).thenAnswer(
      (_) async => const UserPreferences(visitedLocationCodes: ['WALLYS-1']),
    );

    await tester.pumpWidget(buildApp(mockRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text("1 Wally's Walk"));
    await tester.pumpAndSettle();

    expect(find.text('location-wallys-1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/scan/pages/stamps_passport_page_test.dart`
Expected: FAIL — `stamps_passport_page.dart` doesn't exist yet.

- [ ] **Step 3: Add the route name and route**

In `lib/app/router/route_names.dart`, add under the `// QR scan` section:

```dart
  static const String stamps = 'stamps';
```

In `lib/app/router/app_router.dart`, add the import:

```dart
import 'package:mq_journey/features/scan/presentation/pages/stamps_passport_page.dart';
```

Add a new top-level `GoRoute` next to the `/favorites` route (outside the `StatefulShellRoute`, matching the existing pattern for standalone pushed screens):

```dart
      // Stamps passport — Open Day collectible progress screen.
      GoRoute(
        path: '/stamps',
        name: RouteNames.stamps,
        builder: (context, state) => const StampsPassportPage(),
      ),
```

- [ ] **Step 4: Implement `StampsPassportPage`**

Create `lib/features/scan/presentation/pages/stamps_passport_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/scan/domain/contracts/stamp_catalog_entry.dart';
import 'package:mq_journey/features/scan/presentation/widgets/stamp_progress_ring.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';

class StampsPassportPage extends ConsumerWidget {
  const StampsPassportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalogAsync = ref.watch(stampCatalogProvider);
    final visitedCodes = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.visitedLocationCodes ?? const <String>[],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stampsPassportTitle)),
      body: catalogAsync.when(
        data: (catalog) {
          final visitedUpper = visitedCodes
              .map((c) => c.toUpperCase())
              .toSet();
          final collectedCount = catalog
              .where(
                (e) => visitedUpper.contains(e.locationId.toUpperCase()),
              )
              .length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(MqSpacing.space4),
                child: StampProgressRing(
                  collected: collectedCount,
                  total: catalog.length,
                  size: 88,
                ),
              ),
              if (catalog.isNotEmpty && collectedCount == catalog.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: MqSpacing.space4),
                  child: Text(
                    l10n.stampCelebrationCompleteTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MqColors.red,
                    ),
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(MqSpacing.space4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: MqSpacing.space3,
                        mainAxisSpacing: MqSpacing.space3,
                      ),
                  itemCount: catalog.length,
                  itemBuilder: (context, index) {
                    final entry = catalog[index];
                    final collected = visitedUpper.contains(
                      entry.locationId.toUpperCase(),
                    );
                    return _StampCell(
                      entry: entry,
                      collected: collected,
                      onTap: collected
                          ? () => context.push('/location/${entry.locationId}')
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (_, _) => Center(child: Text(l10n.settingsError)),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: MqColors.red)),
      ),
    );
  }
}

class _StampCell extends StatelessWidget {
  const _StampCell({required this.entry, required this.collected, this.onTap});

  final StampCatalogEntry entry;
  final bool collected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: collected
          ? entry.title
          : '${entry.title}. ${l10n.stampsPassportLockedHint}',
      button: collected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(MqSpacing.space2),
          decoration: BoxDecoration(
            color: collected
                ? MqColors.red.withValues(alpha: 0.06)
                : MqColors.charcoal800.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
            border: Border.all(
              color: collected
                  ? MqColors.red.withValues(alpha: 0.25)
                  : MqColors.charcoal800.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (collected)
                Image.asset(
                  entry.stampAsset,
                  width: 40,
                  height: 40,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.local_activity,
                    size: 32,
                    color: MqColors.red,
                  ),
                )
              else
                Icon(
                  Icons.local_activity_outlined,
                  size: 32,
                  color: MqColors.charcoal800.withValues(alpha: 0.25),
                ),
              const SizedBox(height: MqSpacing.space1),
              Text(
                entry.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: collected
                      ? MqColors.contentPrimary
                      : MqColors.contentSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/scan/pages/stamps_passport_page_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/app/router/route_names.dart lib/app/router/app_router.dart lib/features/scan/presentation/pages/stamps_passport_page.dart test/features/scan/pages/stamps_passport_page_test.dart
git commit -m "feat(scan): add /stamps passport page with collected/locked grid"
```

---

## Task 9: Settings "My Stamps" tile

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Create: `test/features/settings/settings_stamps_tile_test.dart`

**Interfaces:**
- Consumes: `RouteNames.stamps` (Task 8), `_TapRow` (existing private widget in `settings_page.dart`).

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/settings_stamps_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/router/route_names.dart';
import 'package:mq_journey/features/map/data/services/offline_maps_service.dart';
import 'package:mq_journey/features/notifications/domain/entities/app_notification.dart';
import 'package:mq_journey/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_journey/features/settings/presentation/pages/settings_page.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockOfflineMapsService extends Mock implements OfflineMapsService {}

class _FakeNotificationsController extends NotificationsController {
  @override
  Future<NotificationsState> build() async => const NotificationsState(
    permissionStatus: NotificationPermissionStatus.granted,
    preferences: [],
  );

  @override
  Future<void> updatePreference(NotificationType type, bool enabled) async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(const UserPreferences());
  });

  testWidgets('My Stamps tile navigates to /stamps', (tester) async {
    final mockSettingsRepository = MockSettingsRepository();
    final mockOfflineMapsService = MockOfflineMapsService();
    when(
      () => mockSettingsRepository.loadPreferences(),
    ).thenAnswer((_) async => const UserPreferences());
    when(() => mockSettingsRepository.savePreferences(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments[0] as UserPreferences,
    );
    when(() => mockOfflineMapsService.isFmtcBackendReady).thenReturn(false);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          name: RouteNames.settings,
          builder: (_, _) => const SettingsPage(),
        ),
        GoRoute(
          path: '/stamps',
          name: RouteNames.stamps,
          builder: (_, _) => const Scaffold(body: Text('stamps-page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
          offlineMapsServiceProvider.overrideWithValue(mockOfflineMapsService),
          notificationsControllerProvider.overrideWith(
            () => _FakeNotificationsController(),
          ),
          selectedBachelorProvider.overrideWithValue(null),
          openDayDataProvider.overrideWith(
            (ref) async => OpenDayData(
              openDayDate: DateTime(2026, 8, 22),
              lastUpdated: DateTime.now(),
              studyAreas: const [],
              bachelors: const [],
              events: const [],
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(SettingsPage));
    final l10n = AppLocalizations.of(context)!;

    await tester.scrollUntilVisible(
      find.text(l10n.settingsMyStampsTile),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text(l10n.settingsMyStampsTile));
    await tester.pumpAndSettle();

    expect(find.text('stamps-page'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/settings_stamps_tile_test.dart`
Expected: FAIL — no "My Stamps" text exists in `SettingsPage` yet.

- [ ] **Step 3: Add the tile**

In `lib/features/settings/presentation/pages/settings_page.dart`, add the import:

```dart
import 'package:mq_journey/app/router/route_names.dart';
import 'package:go_router/go_router.dart';
```

Insert a new section right after the `_OpenDaySection` block (after the line `const SizedBox(height: MqSpacing.space6),` that follows `_OpenDaySection(preferences: preferences),`, i.e. before the `// ── Accessibility & Data section ──` comment):

```dart
                  // ── Open Day Stamps section ───────────────────
                  //
                  // Single entry point into the collectible passport
                  // (/stamps). Kept as its own minimal section rather
                  // than folded into Open Day above so it reads as a
                  // distinct, persistent feature rather than an Open
                  // Day sub-setting.
                  _SectionHeader(title: l10n.stampsPassportTitle),
                  _SettingsCard(
                    children: [
                      _TapRow(
                        icon: Icons.local_activity_outlined,
                        label: l10n.settingsMyStampsTile,
                        value: l10n.settingsMyStampsSubtitle,
                        semanticLabel: l10n.settingsMyStampsTile,
                        hapticsEnabled: preferences.hapticsEnabled,
                        onTap: () => context.pushNamed(RouteNames.stamps),
                      ),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.space6),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/settings_stamps_tile_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full settings suite to check for regressions**

Run: `flutter test test/features/settings/`
Expected: all pass, including the pre-existing `settings_page_test.dart` (its `'renders all preference categories'` test only checks for pre-existing section titles, so it is unaffected by the new section).

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart test/features/settings/settings_stamps_tile_test.dart
git commit -m "feat(settings): add My Stamps tile linking to the Open Day passport"
```

---

## Task 10: Bundle placeholder stamp artwork

**Files:**
- Create: `assets/stamps/_placeholder.png` (1x1 transparent PNG, same role as the existing `assets/photos/_placeholder.jpg`)
- Modify: `pubspec.yaml` (register `assets/stamps/` — non-recursive asset bundling per `CLAUDE.md` §5)

**Interfaces:** none (asset-only task).

- [ ] **Step 1: Add the asset directory to pubspec**

In `pubspec.yaml`, under `flutter: assets:`, add:

```yaml
    - assets/stamps/
```

- [ ] **Step 2: Add a placeholder asset**

Create `assets/stamps/_placeholder.png` — copy the existing 1x1 placeholder used elsewhere in the repo so there is at least one real file in the directory (Flutter errors if an asset directory declared in `pubspec.yaml` doesn't exist):

Run: `cp assets/photos/_placeholder.jpg assets/stamps/_placeholder.png`

- [ ] **Step 3: Verify the app still builds its asset manifest**

Run: `flutter pub get`
Expected: succeeds with no missing-directory errors.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml assets/stamps/_placeholder.png
git commit -m "chore(scan): bundle assets/stamps/ directory for stamp artwork"
```

Note: the 9 real stamp PNGs referenced by `open_day_stamps_catalog.json` (`assets/stamps/wallys-1.png`, etc.) are a content task, not a code task — every `Image.asset` call site in this plan (Tasks 6 and 8) has an `errorBuilder` fallback, so the UI renders correctly with icons until the real artwork is dropped in, same accepted pattern as the missing indoor panorama images (`CLAUDE.md` §5).

---

## Task 11: Full verification gate

**Files:** none (verification only).

- [ ] **Step 1: Format**

Run: `dart format --set-exit-if-changed .`
Expected: exits 0. If it reformats files, review the diff, then re-run to confirm exit 0.

- [ ] **Step 2: Analyze**

Run: `flutter analyze --no-fatal-infos`
Expected: 0 errors/warnings (info-level lints in test files are tolerated per `CLAUDE.md` §6).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass, including every test added in Tasks 1–9. Record the pass count for the changelog entry in Task 12.

- [ ] **Step 4: Regenerate l10n and check untranslated-key tolerance**

Run: `flutter gen-l10n`
Expected: succeeds; no errors (untranslated keys in non-English ARB files are tolerated by CI).

- [ ] **Step 5: Full CI gate**

Run: `scripts/check.sh --quick`
Expected: all steps green — format, analyze, tests, gen-l10n, privacy guard (no analytics package was added), secret scan, no-stale-name guard, no-login-route guard, no-Google guard.

- [ ] **Step 6: Fix any failures**

If any step in Steps 1–5 fails, fix the root cause in the relevant task's files (do not skip hooks or silence the guard) and re-run from Step 1.

---

## Task 12: Update `AGENT.md` and `CHANGELOG.md`

**Files:**
- Modify: `AGENT.md`
- Modify: `CHANGELOG.md`

Per the project's Raouf change protocol (`CLAUDE.md` §7), add a matching entry to the top of both files (newest-first). Use the exact test/analyze numbers captured in Task 11, Step 3.

- [ ] **Step 1: Add the entry to `CHANGELOG.md`**

Insert at the very top of `CHANGELOG.md`:

```markdown
### Raouf: 2026-07-01 (Australia/Sydney) — Open Day Stamps celebration + passport
**Scope:** Scan feature — celebration on confirmed first visit, new `/stamps` passport screen, Settings entry point
**Summary:** Implemented the reward layer on top of the existing QR visit-tracking pipeline per `docs/superpowers/specs/2026-07-01-open-day-stamps-gamification-design.md` via a 10-task TDD plan. (1) Amended `ProgressApi.recordVisit` to return `Future<bool>` (isNewVisit), surfacing what `SettingsController.recordLocationVisit()` already computed but the adapter previously discarded. (2) Added a bundled 9-entry stamp catalogue (`assets/data/open_day_stamps_catalog.json`) + `StampCatalogEntry`/`StampCatalogRepository`. (3) Added the pure `computeStampAward` derivation (no partner/XP code touched). (4) Localised all new copy via ARB keys. (5) `StampProgressRing` shared widget. (6) `StampEarnedSheet` modal celebration with `confetti` + reduce-motion gating + assertive screen-reader announcement (Lottie deferred — no reveal asset authored yet; using a built-in scale/fade instead). (7) Wired `ScanPage` to show the sheet on a confirmed first visit and a subdued "already collected" snackbar on re-scan. (8) New `/stamps` route + `StampsPassportPage` grid (collected/locked cells, progress ring, passport-complete banner). (9) New "My Stamps" tile in Settings. (10) Bundled `assets/stamps/` placeholder directory — real stamp artwork is a follow-up content task.
**Files Changed:** `lib/features/scan/domain/contracts/progress_api.dart`, `lib/features/scan/domain/contracts/stamp_catalog_entry.dart`, `lib/features/scan/data/adapters/settings_progress_api_adapter.dart`, `lib/features/scan/domain/fakes/fake_progress_api.dart`, `lib/features/scan/data/repositories/stamp_catalog_repository.dart`, `lib/features/scan/domain/services/stamp_award_calculator.dart`, `lib/features/scan/presentation/widgets/stamp_progress_ring.dart`, `lib/features/scan/presentation/widgets/stamp_earned_sheet.dart`, `lib/features/scan/presentation/pages/scan_page.dart`, `lib/features/scan/presentation/pages/stamps_passport_page.dart`, `lib/features/scan/providers/scan_providers.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/app/router/route_names.dart`, `lib/app/router/app_router.dart`, `lib/app/l10n/app_en.arb`, `assets/data/open_day_stamps_catalog.json`, `assets/stamps/_placeholder.png`, `pubspec.yaml`, plus new tests under `test/features/scan/` and `test/features/settings/`
**Verification:** `flutter analyze` — 0 errors; `flutter test` — <RECORD ACTUAL PASS COUNT FROM TASK 11 STEP 3> passed; `scripts/check.sh --quick` — all green.
**Follow-ups:**
- Real stamp artwork (`assets/stamps/<locationId>.png`, 9 files) and a Lottie stamp-reveal asset are still pending — placeholders/fallback icons in use, no code change needed once supplied.
- `OpenDayGamification` (flat 50-XP/visit) predates this feature and is intentionally untouched; cleaning it up is a partner-owned economy migration, not in scope here.
- No 4th bottom-nav tab was added for the passport by design (`/stamps` is a pushed route from Settings + the celebration CTA); revisit if usage data shows the Settings tile is too low-discoverability.
```

- [ ] **Step 2: Add the mirrored entry to `AGENT.md`**

`AGENT.md` uses the same changelog-entry format appended at a "Recent Changes"-style location — check the file for where existing dated entries live (if `AGENT.md` has a running changelog section, prepend there; otherwise add a new `## Recent Changes` section above the first `##` heading with the same entry content as Step 1). Use the identical entry text from Step 1 for consistency between the two files.

- [ ] **Step 3: Commit**

```bash
git add AGENT.md CHANGELOG.md
git commit -m "docs: changelog for Open Day stamps celebration + passport"
```
