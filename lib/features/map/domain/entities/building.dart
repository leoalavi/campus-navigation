import 'package:flutter/foundation.dart';
import 'package:mq_navigation/features/map/domain/entities/campus_point.dart';

/// A campus building with its metadata and GPS coordinates.
@immutable
class Building {
  const Building({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.address,
    this.category = BuildingCategory.other,
    this.latitude,
    this.longitude,
    this.entranceLatitude,
    this.entranceLongitude,
    this.levels,
    this.wheelchair = false,
    this.tags = const [],
    this.aliases = const [],
    this.searchTokens = const [],
    this.gridRef,
    this.campusX,
    this.campusY,
    this.facultyGroup,
    this.studentServicesGroups = const [],
    this.campusHubGroups = const [],
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? address;
  final BuildingCategory category;
  final double? latitude;
  final double? longitude;
  final double? entranceLatitude;
  final double? entranceLongitude;
  final int? levels;
  final bool wheelchair;
  final List<String> tags;
  final List<String> aliases;
  final List<String> searchTokens;
  final String? gridRef;
  final double? campusX;
  final double? campusY;

  /// Which of the four MQ faculty groups this building belongs to,
  /// if any. Drives the **Faculty** category two-level drill-down on
  /// the map: top level shows the four [FacultyGroup] cards, second
  /// level shows only buildings whose `facultyGroup == selected`.
  ///
  /// `null` means the building is not assigned to a faculty group —
  /// it can still be tagged `faculty` for legacy search tokens, but
  /// it won't appear under any specific drill-down branch.
  final FacultyGroup? facultyGroup;

  /// Which **Student Services** sub-groups this building belongs to,
  /// if any. Drives the two-level drill-down on the Student Services
  /// chip — the top level shows the seven [StudentServicesGroup]
  /// cards, the second level shows buildings whose
  /// `studentServicesGroups` contains the selected group.
  ///
  /// **A list, not a single value**, because one building (notably
  /// 18 Wally's Walk / Service Connect) genuinely hosts services
  /// across multiple sub-groups (Admin + IT + Academic + Careers).
  /// Faculty stays singular because every faculty building has one
  /// home faculty.
  final List<StudentServicesGroup> studentServicesGroups;

  /// Which **Campus Hub** sub-groups this building belongs to. Same
  /// list-based design as [studentServicesGroups] — for example
  /// `1CC` (1 Central Courtyard) is both a Student Life hub and
  /// hosts the Graduation Venue.
  final List<CampusHubGroup> campusHubGroups;

  factory Building.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final entrance = json['entranceLocation'] as Map<String, dynamic>?;
    final campusLocation = json['campusLocation'] as Map<String, dynamic>?;
    final id = json['id'] as String;

    return Building(
      id: id,
      code: (json['code'] as String?) ?? id,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      category: BuildingCategory.fromString(
        json['category'] as String? ?? 'other',
      ),
      latitude:
          (json['latitude'] as num?)?.toDouble() ??
          (location?['lat'] as num?)?.toDouble(),
      longitude:
          (json['longitude'] as num?)?.toDouble() ??
          (location?['lng'] as num?)?.toDouble(),
      entranceLatitude:
          (json['entranceLatitude'] as num?)?.toDouble() ??
          (entrance?['lat'] as num?)?.toDouble(),
      entranceLongitude:
          (json['entranceLongitude'] as num?)?.toDouble() ??
          (entrance?['lng'] as num?)?.toDouble(),
      levels: (json['levels'] as num?)?.toInt(),
      wheelchair: json['wheelchair'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      aliases: (json['aliases'] as List<dynamic>?)?.cast<String>() ?? [],
      searchTokens:
          (json['searchTokens'] as List<dynamic>?)?.cast<String>() ?? [],
      gridRef: json['gridRef'] as String?,
      campusX:
          (campusLocation?['x'] as num?)?.toDouble() ??
          (json['campusX'] as num?)?.toDouble(),
      campusY:
          (campusLocation?['y'] as num?)?.toDouble() ??
          (json['campusY'] as num?)?.toDouble(),
      facultyGroup: FacultyGroup.fromJson(json['facultyGroup'] as String?),
      studentServicesGroups: _parseGroupList<StudentServicesGroup>(
        json['studentServicesGroups'],
        StudentServicesGroup.fromJson,
      ),
      campusHubGroups: _parseGroupList<CampusHubGroup>(
        json['campusHubGroups'],
        CampusHubGroup.fromJson,
      ),
    );
  }

  static List<T> _parseGroupList<T>(Object? raw, T? Function(String?) parser) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final item in raw) {
      final parsed = parser(item is String ? item : null);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'address': address,
    'category': category.name,
    'latitude': latitude,
    'longitude': longitude,
    'entranceLatitude': entranceLatitude,
    'entranceLongitude': entranceLongitude,
    'location': latitude != null ? {'lat': latitude, 'lng': longitude} : null,
    'entranceLocation': entranceLatitude != null
        ? {'lat': entranceLatitude, 'lng': entranceLongitude}
        : null,
    'levels': levels,
    'wheelchair': wheelchair,
    'tags': tags,
    'aliases': aliases,
    'searchTokens': searchTokens,
    'gridRef': gridRef,
    'campusX': campusX,
    'campusY': campusY,
    'campusLocation': hasCampusCoordinates
        ? {'x': campusX, 'y': campusY}
        : null,
    'facultyGroup': facultyGroup?.id,
    'studentServicesGroups': studentServicesGroups.map((g) => g.id).toList(),
    'campusHubGroups': campusHubGroups.map((g) => g.id).toList(),
  };

  /// Best coordinate for routing: entrance if available, otherwise building center.
  double? get routingLatitude => entranceLatitude ?? latitude;
  double? get routingLongitude => entranceLongitude ?? longitude;
  bool get hasGeographicCoordinates => latitude != null && longitude != null;
  bool get hasCampusCoordinates => campusX != null && campusY != null;
  CampusPoint? get campusPoint =>
      hasCampusCoordinates ? CampusPoint(x: campusX!, y: campusY!) : null;

  bool get isHighTraffic {
    return const <String>{
      'LIB',
      '18WW',
      '1CC',
      'MUSE',
      '14SCO',
      '12WW',
    }.contains(id.toUpperCase());
  }

  /// Whether this building matches a search query.
  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return id.toLowerCase().contains(q) ||
        code.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        category.name.toLowerCase().contains(q) ||
        (description?.toLowerCase().contains(q) ?? false) ||
        (address?.toLowerCase().contains(q) ?? false) ||
        aliases.any((a) => a.toLowerCase().contains(q)) ||
        searchTokens.any((token) => token.toLowerCase().contains(q)) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Building && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Building($id, $name)';
}

enum BuildingCategory {
  academic,
  services,
  health,
  food,
  sports,
  venue,
  research,
  residential,
  parking,
  transport,
  smoking,
  other;

  static BuildingCategory fromString(String value) {
    return BuildingCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BuildingCategory.other,
    );
  }
}

/// The four top-level Macquarie University faculty groups used by
/// the **Faculty** category browse drill-down. The order here is the
/// canonical display order on the first-level faculty list.
///
/// The string [id] is the on-disk JSON identifier in
/// `assets/data/buildings.json`. **Do not rename** these without also
/// migrating the asset and bumping the building registry cache key.
enum FacultyGroup {
  arts(
    id: 'arts',
    label: 'Faculty of Arts',
    description: 'Humanities, Law, Education, MMCCS',
    icon: '\u{1F3DB}',
  ),
  business(
    id: 'business',
    label: 'Macquarie Business School',
    description: 'Business, Economics, Marketing',
    icon: '\u{1F4BC}',
  ),
  mhhs(
    id: 'mhhs',
    label: 'Faculty of Medicine, Health and Human Sciences',
    description: 'Health Sciences, Psychology, Clinical',
    icon: '\u{2695}',
  ),
  scienceEngineering(
    id: 'science_engineering',
    label: 'Faculty of Science and Engineering',
    description: 'Sciences, Engineering, Computing',
    icon: '\u{1F52C}',
  );

  const FacultyGroup({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final String icon;

  static FacultyGroup? fromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final group in FacultyGroup.values) {
      if (group.id == value) return group;
    }
    return null;
  }
}

/// Sub-groups inside the **Student Services** browse drill-down.
/// Top-level Student Services chip first shows these groups, second
/// level shows buildings whose [Building.studentServicesGroups]
/// contains the selected group. The order below is the canonical
/// display order on the first-level list.
///
/// The string [id] is the on-disk JSON identifier in
/// `assets/data/buildings.json` — **never rename** without bumping
/// the registry cache key in [`BuildingRegistrySource`].
enum StudentServicesGroup {
  support(
    id: 'support',
    label: 'Support & Wellbeing',
    description: 'Counselling, welfare, chaplaincy, childcare, hearing hub',
    icon: '\u{1F49A}',
  ),
  admin(
    id: 'admin',
    label: 'Administration & Enquiries',
    description: 'Service Connect, Chancellery, enrolment, fees',
    icon: '\u{1F4CB}',
  ),
  academic(
    id: 'academic',
    label: 'Academic Help & Learning Support',
    description: 'Learning Connect, Writing & Numeracy',
    icon: '\u{1F4DA}',
  ),
  it(
    id: 'it',
    label: 'IT & Technology Help',
    description: 'IT Service Desk, Tech Bar',
    icon: '\u{1F5A5}',
  ),
  security(
    id: 'security',
    label: 'Security & Emergency',
    description: '24/7 security, help points, first aid',
    icon: '\u{1F6E1}',
  ),
  careers(
    id: 'careers',
    label: 'Careers & Employability',
    description: 'Career and Employment Service',
    icon: '\u{1F4BC}',
  ),
  inclusion(
    id: 'inclusion',
    label: 'Accessibility & Inclusion',
    description: 'Walanga Muru, Macquarie International, accessibility',
    icon: '\u{1F30F}',
  );

  const StudentServicesGroup({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final String icon;

  static StudentServicesGroup? fromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final group in StudentServicesGroup.values) {
      if (group.id == value) return group;
    }
    return null;
  }
}

/// Sub-groups inside the **Campus Hub** browse drill-down. Same
/// structural contract as [StudentServicesGroup] / [FacultyGroup].
/// The order here is the canonical display order — accommodation
/// + sport + study lead because that's what students browse for
/// most often, and bike + smoking trail because they're niche but
/// product-required for completeness.
enum CampusHubGroup {
  accommodation(
    id: 'accommodation',
    label: 'Accommodation',
    description: 'On-campus residential colleges & student housing',
    icon: '\u{1F3E0}',
  ),
  sport(
    id: 'sport',
    label: 'Sport Facilities',
    description: 'Sport & Aquatic Centre, fields, courts, pavilion',
    icon: '\u{26BD}',
  ),
  study(
    id: 'study',
    label: 'Study Spaces',
    description: 'Library, MUSE, 4 Research Park Drive',
    icon: '\u{1F4D6}',
  ),
  museums(
    id: 'museums',
    label: 'Museums & Galleries',
    description: 'History Museum, Art Gallery, Biology Discovery',
    icon: '\u{1F5BC}',
  ),
  studentLife(
    id: 'student_life',
    label: 'Student Life & Social',
    description: 'The Hub, theatres, social courtyards',
    icon: '\u{1F389}',
  ),
  childcare(
    id: 'childcare',
    label: 'Childcare & Family Support',
    description: 'Banksia, Gumnut, Mia Mia, Waratah cottages',
    icon: '\u{1F476}',
  ),
  health(
    id: 'health',
    label: 'Everyday Campus Health',
    description: 'GP & Physio, Hospital, Pharmacy, Woolcock',
    icon: '\u{1FA7A}',
  ),
  bike(
    id: 'bike',
    label: 'Bike Facilities',
    description: 'Bike racks, hubs, repair stations',
    icon: '\u{1F6B2}',
  ),
  smoking(
    id: 'smoking',
    label: 'Smoking Areas',
    description: 'Designated outdoor smoking zones',
    icon: '\u{1F6AC}',
  );

  const CampusHubGroup({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final String icon;

  static CampusHubGroup? fromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final group in CampusHubGroup.values) {
      if (group.id == value) return group;
    }
    return null;
  }
}
