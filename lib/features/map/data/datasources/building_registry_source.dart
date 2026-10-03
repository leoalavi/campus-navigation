import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mq_navigation/core/logging/app_logger.dart';
import 'package:mq_navigation/core/security/secure_storage_service.dart';
import 'package:mq_navigation/features/map/domain/entities/building.dart';

/// Versioned cache key. **Bump the suffix whenever `buildings.json`
/// changes shape (new tags, new aliases, schema changes)** — every
/// install will invalidate its previous cache on next launch and
/// re-hydrate from the bundled asset. The previous unversioned key
/// (`'building_registry'`) is intentionally never re-used so installs
/// upgrading from older builds never serve stale enrichment data.
///
/// Version history:
///   v2 — Open Day 2026 release: `faculty`, `campus hub`, and
///        `student services` tags, plus 66 cross-departmental aliases
///        and the Gale History Museum entry.
///   v3 — Campus tour script enrichment: aliases + searchTokens for
///        Service Connect, IT Service Desk, Learning Connect, Career
///        and Employment Service (18WW); Michael Kirby Building, Law
///        Commons, Moot Courts (17WW); Arts Precinct, Faculty of Arts
///        Offices, A/B/C aliases (25BWW); The Hub, student group
///        stalls (1CC); Lincoln Building, Research Office (16WW);
///        15-17 Gymnasium Road on Student Accommodation; Macquarie
///        Theatre under Campus Hub. Three duplicate sub-building
///        entries removed (17WWMICHAE, 18WWSERVIC, 16WWLINCOL).
///   v4 — Campus tour script pages 4–8: dual-address 14SCO ↔ 12WW;
///        Muslim Prayer Rooms, Macquarie International, MQ University
///        College, Numeracy Centre, Emergency Blue Help Point, Mason
///        Theatre on 14SCO; Walanga Muru Pavilion / Jannawi context
///        on WALU; Australian Hearing Hub + Student Wellbeing +
///        Accessibility + Counselling + Welfare on 16UA; Ainsworth /
///        Clinical Education on AINS; Frank the Bear on 6WW; T1 +
///        theatres on LOTUS and 29WW; MUSAC + sport-and-aquatic
///        aliases on SPORT; Macquarie University History Museum on
///        GALEHIST; Macquarie University Village on MQV; 2SER 107.3
///        on CHAP (10 Hadenfeld); Campus Security Office on LIB;
///        2 Technology Place on CLINIC; Biological Sciences Museum
///        aliases on BIODISC and 6SR; parking-on-campus tokens on
///        every parking entry. Four duplicate stubs removed (27WW,
///        16UAAUSTRA, 25CWW, 1WW).
///   v5 — Category browse refresh: introduces `facultyGroup` per
///        faculty building (4 groups: arts / business / mhhs /
///        science_engineering) to power the two-level Faculty
///        drill-down. Cleaner Student Services + Campus Hub labels
///        (Service Connect / IT / Learning Support; Lincoln Building;
///        Counselling & Wellbeing; The Hub / Student Life; etc.).
///        Removed duplicate stubs 16MW (folded into LIB) and 6SR
///        (folded into BIODISC). Demoted 6WW and 16WW from the
///        Campus Hub bucket — they're primarily Faculty/Research
///        buildings, not student-life destinations. 11WW labelled as
///        Tutorial Rooms; LOTUS labelled as T1 Lecture Theatre.
///   v6 — PDF/Maps source-of-truth audit (Aug 2025 Location Guide +
///        public Maps page). Recategorised every campus parking lot
///        (6 general + 2 hospital) into `parking` so they all surface
///        under the Parking chip with consistent enum + tag. Promoted
///        accommodation parents (DLC, RMC, VILLAS, Central Courtyard,
///        Morling), all sport facilities (FIELDS, BBALL, Ron Reilly,
///        10GR), and study spaces (MUSE, 4RPD) into Campus Hub via the
///        `campus hub` tag — Campus Hub now correctly covers
///        accommodation + sport + study per the brief. Surfaced
///        Security & Information at 4LR under Student Services and
///        enriched SEC with help-point search tokens. Pulled in 60+
///        PDF aliases (Service Connect first-aid room, Tech Bar, MMI,
///        Pharmacy, IELTS/PTE, MQ Academy, Future Students, Speech &
///        Hearing, Mindspot, MMCCS, Herbarium, Lachlan Macquarie
///        Room, Sporting Hall of Fame, etc.) onto the existing parent
///        buildings rather than spawning new markers. Removed five
///        duplicate/excluded entries: EAST2 (= PEAST2), EAST3
///        (= PEAST3), 75TR (= 75TAL), BIKEHUB and BIKEHUBE (Bike
///        Facilities excluded by product). 145 → 140 buildings.
///   v7 — Two-level browse drill-down for Student Services and Campus
///        Hub (mirrors the existing Faculty pattern). Adds two new
///        list fields per building — `studentServicesGroups` and
///        `campusHubGroups` — driving the new sub-group cards. Re-adds
///        Bike Facilities (25 racks + 2 hubs + 2 repair = 29 entries)
///        and Smoking Areas (6 entries) per the revised brief — both
///        placed under Campus Hub as their own sub-groups so they're
///        browsable but stay out of the main map clutter unless the
///        user has actively drilled in. 140 → 175 buildings.
///   v8 — Final demo polish + verification audit. Folded twelve
///        long-standing duplicate pairs into their canonical
///        student-friendly entries (8HA→INCUB, 11GR→LIGHT, 5GR→OBS,
///        10GR→SPORT, 21WW→MQTH, 8LR→BANK, 3SR→METS, 19ERTHECHA→19ER,
///        2TP→CLINIC, MACQUARIEU→HOSP, CHAP→10HA,
///        LAKESIDEHO→LACH). Each merge transferred aliases, search
///        tokens, and tags to the kept entry, so search by the old
///        ID still resolves. Stripped misleading "130 Herring Road"
///        and "136 Herring Road" addresses from 130HR
///        (Central Courtyard) and 136HR (Morling) — those addresses
///        belong to DLC and RMC respectively, which already exist as
///        their own entries. Removed NEXTSCHOOL from the
///        Accessibility & Inclusion group because it's a partner
///        K-12 D/deaf school, not an MQ student service. Relabeled
///        eleven canonical entries with student-friendly compound
///        names (e.g. "Macquarie University Hospital (3 Technology
///        Place)") so the address context shows directly in the row.
///        175 → 163 buildings.
///   v9 — PDF source-of-truth alignment pass. All 20 fixes from the May 2026
///        Location Guide audit: (1) FIELDS address corrected to "Corner
///        Talavera Road & Culloden Roads" (was incorrectly showing student
///        accommodation address); (2) 4LR duplicate deleted — aliases/tokens
///        absorbed into canonical SEC entry; (3) 10HA gains facultyGroup=arts
///        and gridRef=R6 (hosts MMCCS / Dept of Media); (4–7) All four
///        childcare centres (BANK, GUMNUT, MIAMIA, WARATAH) now correctly
///        carry studentServicesGroups=["support"], with Banksia, Gumnut, and
///        Waratah also enriched with aliases and searchTokens; (8) LIB gains
///        studentServicesGroups=["academic"]; (9) GALLERY enriched as the
///        canonical Art Gallery entry, Art Gallery alias/token removed from
///        19ER; (10) 6WW gains campusHubGroups=["museums"] for the Herbarium;
///        (11) SPORT gains campusHubGroups=["museums"] for Sporting Hall of
///        Fame; (12) LOTUS: spurious facultyGroup=science_engineering removed;
///        (13) 18WW gains studentServicesGroups="security" (First Aid Room);
///        (14) 8SCO gains studentServicesGroups="admin"; (15) PRICE fully
///        enriched (aliases, searchTokens, campusHubGroups=["student_life"]);
///        (16) CCMQ: address→"10 Gymnasium Road", gridRef=J12; (17) 1CC:
///        gridRef corrected K19→K18; (18) METS: studentServicesGroups=
///        ["academic"]; (19) INCUB: studentServicesGroups=["careers"],
///        campusHubGroups=["student_life"]; (20) 1EXR spurious stub deleted.
///        163 → 161 buildings.
const _cacheKey = 'building_registry.v9';
const _assetPath = 'assets/data/buildings.json';

/// Data source for the campus building registry.
/// Fetches from Supabase and caches locally in secure storage.
class BuildingRegistrySource {
  BuildingRegistrySource({required this.secureStorage});

  final SecureStorageService secureStorage;

  /// Load buildings: try cache first, then fetch from Supabase.
  Future<List<Building>> getBuildings({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached != null && cached.isNotEmpty) {
        AppLogger.debug('Building registry loaded from cache', cached.length);
        return cached;
      }
    }

    try {
      final buildings = await _fetchFromSupabase();
      await _saveToCache(buildings);
      AppLogger.info(
        'Building registry fetched from Supabase',
        buildings.length,
      );
      return buildings;
    } catch (e, s) {
      AppLogger.error('Failed to fetch building registry', e, s);
      final cached = await _loadFromCache();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      // If network fails and no secure storage cache exists (e.g. fresh install
      // without internet), fall back to the bundled JSON asset exported at build time.
      return _loadFromAsset();
    }
  }

  Future<List<Building>> _fetchFromSupabase() async {
    // Query the building data from Supabase.
    // This assumes a `buildings` table or RPC exists, or falls back to app_config.
    // For now, try app_config where key = 'building_registry'.
    final response = await Supabase.instance.client
        .from('app_config')
        .select('value')
        .eq('key', 'building_registry')
        .maybeSingle();

    if (response == null || response['value'] == null) {
      return _loadFromAsset();
    }

    final data = response['value'] as List<dynamic>;
    return data
        .map((e) => Building.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Building>> _loadFromAsset() async {
    final raw = await rootBundle.loadString(_assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    final buildings = list
        .map((item) => Building.fromJson(item as Map<String, dynamic>))
        .toList();
    await _saveToCache(buildings);
    return buildings;
  }

  Future<List<Building>?> _loadFromCache() async {
    try {
      final cached = await secureStorage.read(_cacheKey);
      if (cached == null) return null;
      final list = jsonDecode(cached) as List<dynamic>;
      return list
          .map((e) => Building.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.warning('Failed to load building cache', e);
      return null;
    }
  }

  Future<void> _saveToCache(List<Building> buildings) async {
    try {
      final json = jsonEncode(buildings.map((b) => b.toJson()).toList());
      await secureStorage.write(_cacheKey, json);
    } catch (e) {
      AppLogger.warning('Failed to save building cache', e);
    }
  }
}

final buildingRegistrySourceProvider = Provider<BuildingRegistrySource>((ref) {
  return BuildingRegistrySource(
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});

/// Provides the cached building list.
final buildingRegistryProvider = FutureProvider<List<Building>>((ref) {
  return ref.watch(buildingRegistrySourceProvider).getBuildings();
});
