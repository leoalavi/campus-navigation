import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';

@immutable
class UserPreferences {
  const UserPreferences({
    this.hasCompletedOnboarding = false,
    this.commuteMode = 'none',
    this.favoriteDirection = '',
    this.favoriteRoute = '',
    this.favoriteStopId = '',
    this.favoriteStopName = '',
    this.themeMode = ThemeMode.system,
    this.localeCode,
    this.notificationsEnabled = true,
    this.defaultTravelMode = TravelMode.walk,
    this.lowDataMode = false,
    this.reducedMotion = false,
    this.hapticsEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '23:00',
    this.quietHoursEnd = '08:00',
    this.highContrastMap = false,
    this.selectedBachelorId,
    this.openDayRemindersEnabled = true,
    this.openDayReminderMinutesBefore = 15,
    this.showSuggestedStops = true,
    this.savedOpenDayEventIds = const <String>[],
    this.savedStopIds = const <String>[],
    this.visitedLocationCodes = const <String>[],
  });

  final bool hasCompletedOnboarding;
  final ThemeMode themeMode;
  final String commuteMode;
  final String favoriteDirection;
  final String favoriteRoute;
  final String favoriteStopId;
  final String favoriteStopName;
  final String? localeCode;
  final bool notificationsEnabled;
  final TravelMode defaultTravelMode;
  final bool lowDataMode;
  final bool reducedMotion;
  final bool hapticsEnabled;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool highContrastMap;

  /// True once a full campus tile download has completed successfully.

  final String? selectedBachelorId;
  final bool openDayRemindersEnabled;
  final int openDayReminderMinutesBefore;

  /// Minimal Open Day toggle — when off, the personalised Suggested Stops
  /// section is hidden on Home, keeping the screen lean for users who only
  /// want the schedule.
  final bool showSuggestedStops;

  /// IDs of Open Day events (sessions) the user has saved to "Your Day".
  /// Kept as an ordered, immutable list; the itinerary sorts by start time.
  final List<String> savedOpenDayEventIds;

  /// IDs of suggested stops the user has saved to "Your Day". Sessions and
  /// stops together form the unified `UserDayItem` list (see
  /// `userDayItemsProvider`).
  final List<String> savedStopIds;

  /// Building codes the user has visited (e.g. via a QR scan). A set-like
  /// list — the gamification layer awards XP only on first visit, so
  /// duplicates are ignored. The QR/location feature records visits here.
  final List<String> visitedLocationCodes;

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  bool isOpenDayEventSaved(String eventId) =>
      savedOpenDayEventIds.contains(eventId);

  bool isStopSaved(String stopId) => savedStopIds.contains(stopId);

  bool hasVisited(String buildingCode) =>
      visitedLocationCodes.contains(buildingCode);

  UserPreferences copyWith({
    bool? hasCompletedOnboarding,
    ThemeMode? themeMode,
    String? commuteMode,
    String? favoriteDirection,
    String? favoriteRoute,
    String? favoriteStopId,
    String? favoriteStopName,
    String? localeCode,
    bool clearLocale = false,
    bool? notificationsEnabled,
    TravelMode? defaultTravelMode,
    bool? lowDataMode,
    bool? reducedMotion,
    bool? hapticsEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? highContrastMap,
    String? selectedBachelorId,
    bool clearSelectedBachelor = false,
    bool? openDayRemindersEnabled,
    int? openDayReminderMinutesBefore,
    bool? showSuggestedStops,
    List<String>? savedOpenDayEventIds,
    List<String>? savedStopIds,
    List<String>? visitedLocationCodes,
  }) {
    return UserPreferences(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      themeMode: themeMode ?? this.themeMode,
      commuteMode: commuteMode ?? this.commuteMode,
      favoriteDirection: favoriteDirection ?? this.favoriteDirection,
      favoriteRoute: favoriteRoute ?? this.favoriteRoute,
      favoriteStopId: favoriteStopId ?? this.favoriteStopId,
      favoriteStopName: favoriteStopName ?? this.favoriteStopName,
      localeCode: clearLocale ? null : localeCode ?? this.localeCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultTravelMode: defaultTravelMode ?? this.defaultTravelMode,
      lowDataMode: lowDataMode ?? this.lowDataMode,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      highContrastMap: highContrastMap ?? this.highContrastMap,
      selectedBachelorId: clearSelectedBachelor
          ? null
          : (selectedBachelorId ?? this.selectedBachelorId),
      openDayRemindersEnabled:
          openDayRemindersEnabled ?? this.openDayRemindersEnabled,
      openDayReminderMinutesBefore:
          openDayReminderMinutesBefore ?? this.openDayReminderMinutesBefore,
      showSuggestedStops: showSuggestedStops ?? this.showSuggestedStops,
      savedOpenDayEventIds: savedOpenDayEventIds ?? this.savedOpenDayEventIds,
      savedStopIds: savedStopIds ?? this.savedStopIds,
      visitedLocationCodes: visitedLocationCodes ?? this.visitedLocationCodes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferences &&
          runtimeType == other.runtimeType &&
          hasCompletedOnboarding == other.hasCompletedOnboarding &&
          themeMode == other.themeMode &&
          commuteMode == other.commuteMode &&
          favoriteDirection == other.favoriteDirection &&
          favoriteRoute == other.favoriteRoute &&
          favoriteStopId == other.favoriteStopId &&
          favoriteStopName == other.favoriteStopName &&
          localeCode == other.localeCode &&
          notificationsEnabled == other.notificationsEnabled &&
          defaultTravelMode == other.defaultTravelMode &&
          lowDataMode == other.lowDataMode &&
          reducedMotion == other.reducedMotion &&
          hapticsEnabled == other.hapticsEnabled &&
          quietHoursEnabled == other.quietHoursEnabled &&
          quietHoursStart == other.quietHoursStart &&
          quietHoursEnd == other.quietHoursEnd &&
          highContrastMap == other.highContrastMap &&
          selectedBachelorId == other.selectedBachelorId &&
          openDayRemindersEnabled == other.openDayRemindersEnabled &&
          openDayReminderMinutesBefore == other.openDayReminderMinutesBefore &&
          showSuggestedStops == other.showSuggestedStops &&
          listEquals(savedOpenDayEventIds, other.savedOpenDayEventIds) &&
          listEquals(savedStopIds, other.savedStopIds) &&
          listEquals(visitedLocationCodes, other.visitedLocationCodes);

  @override
  int get hashCode => Object.hashAll([
    hasCompletedOnboarding,
    themeMode,
    commuteMode,
    favoriteDirection,
    favoriteRoute,
    favoriteStopId,
    favoriteStopName,
    localeCode,
    notificationsEnabled,
    defaultTravelMode,
    lowDataMode,
    reducedMotion,
    hapticsEnabled,
    quietHoursEnabled,
    quietHoursStart,
    quietHoursEnd,
    highContrastMap,
    selectedBachelorId,
    openDayRemindersEnabled,
    openDayReminderMinutesBefore,
    showSuggestedStops,
    Object.hashAll(savedOpenDayEventIds),
    Object.hashAll(savedStopIds),
    Object.hashAll(visitedLocationCodes),
  ]);
}
