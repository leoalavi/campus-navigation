import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/core/security/secure_storage_service.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

const _themeModeKey = 'settings.theme_mode';
const _localeCodeKey = 'settings.locale_code';
const _notificationsEnabledKey = 'settings.notifications_enabled';
const _defaultTravelModeKey = 'settings.default_travel_mode';
const _lowDataModeKey = 'settings.low_data_mode';
const _reducedMotionKey = 'settings.reduced_motion';
const _hapticsEnabledKey = 'settings.haptics_enabled';
const _quietHoursEnabledKey = 'settings.quiet_hours_enabled';
const _quietHoursStartKey = 'settings.quiet_hours_start';
const _quietHoursEndKey = 'settings.quiet_hours_end';
const _highContrastMapKey = 'settings.high_contrast_map';
const _offlineCampusMapsEnabledKey = 'settings.offline_campus_maps_enabled';
const _offlineCampusMapsDownloadedKey =
    'settings.offline_campus_maps_downloaded';
const _commuteModeKey = 'settings.commute_mode';
const _favoriteDirectionKey = 'settings.favorite_direction';
const _favoriteRouteKey = 'settings.favorite_route';
const _favoriteStopIdKey = 'settings.favorite_stop_id';
const _favoriteStopNameKey = 'settings.favorite_stop_name';
const _selectedBachelorIdKey = 'settings.open_day.bachelor_id';
const _openDayRemindersEnabledKey = 'settings.open_day.reminders_enabled';
const _openDayReminderMinutesKey = 'settings.open_day.reminder_minutes';
const _showSuggestedStopsKey = 'settings.open_day.show_suggested_stops';
const _savedOpenDayEventIdsKey = 'settings.open_day.saved_event_ids';
const _savedStopIdsKey = 'settings.open_day.saved_stop_ids';
const _visitedLocationCodesKey = 'settings.open_day.visited_codes';
const _hasCompletedOnboardingKey = 'settings.has_completed_onboarding';

abstract interface class SettingsRepository {
  Future<UserPreferences> loadPreferences();
  Future<UserPreferences> savePreferences(UserPreferences preferences);
  Future<void> wipeAllLocalData();
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return LocalSettingsRepository(storage: storage);
});

class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository({required SecureStorageService storage})
    : _storage = storage;

  final SecureStorageService _storage;

  @override
  Future<UserPreferences> loadPreferences() async {
    try {
      final themeModeString = await _storage.read(_themeModeKey);
      final localeCode = await _storage.read(_localeCodeKey);
      final notificationsEnabled = await _storage.read(
        _notificationsEnabledKey,
      );
      final defaultTravelModeString = await _storage.read(
        _defaultTravelModeKey,
      );
      final lowDataMode = await _storage.read(_lowDataModeKey);
      final reducedMotion = await _storage.read(_reducedMotionKey);
      final hapticsEnabled = await _storage.read(_hapticsEnabledKey);
      final quietHoursEnabled = await _storage.read(_quietHoursEnabledKey);
      final quietHoursStart = await _storage.read(_quietHoursStartKey);
      final quietHoursEnd = await _storage.read(_quietHoursEndKey);
      final highContrastMap = await _storage.read(_highContrastMapKey);
      final offlineCampusMapsEnabled = await _storage.read(
        _offlineCampusMapsEnabledKey,
      );
      final offlineCampusMapsDownloaded = await _storage.read(
        _offlineCampusMapsDownloadedKey,
      );
      final commuteMode = await _storage.read(_commuteModeKey);
      final favoriteDirection = await _storage.read(_favoriteDirectionKey);
      final favoriteRoute = await _storage.read(_favoriteRouteKey);
      final favoriteStopId = await _storage.read(_favoriteStopIdKey);
      final favoriteStopName = await _storage.read(_favoriteStopNameKey);
      final selectedBachelorId = await _storage.read(_selectedBachelorIdKey);
      final openDayRemindersEnabled = await _storage.read(
        _openDayRemindersEnabledKey,
      );
      final openDayReminderMinutes = await _storage.read(
        _openDayReminderMinutesKey,
      );
      final showSuggestedStops = await _storage.read(_showSuggestedStopsKey);
      final savedOpenDayEventIds = await _storage.read(
        _savedOpenDayEventIdsKey,
      );
      final savedStopIds = await _storage.read(_savedStopIdsKey);
      final visitedLocationCodes = await _storage.read(
        _visitedLocationCodesKey,
      );
      final hasCompletedOnboarding = await _storage.read(
        _hasCompletedOnboardingKey,
      );

      final localThemeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == themeModeString,
        orElse: () => ThemeMode.system,
      );

      final defaultTravelMode = TravelMode.values.firstWhere(
        (m) => m.name == defaultTravelModeString,
        orElse: () => TravelMode.walk,
      );

      return UserPreferences(
        hasCompletedOnboarding: hasCompletedOnboarding == 'true',
        themeMode: localThemeMode,
        localeCode: localeCode,
        notificationsEnabled: notificationsEnabled != 'false',
        defaultTravelMode: defaultTravelMode,
        lowDataMode: lowDataMode == 'true',
        reducedMotion: reducedMotion == 'true',
        hapticsEnabled: hapticsEnabled != 'false',
        quietHoursEnabled: quietHoursEnabled == 'true',
        quietHoursStart: quietHoursStart ?? '23:00',
        quietHoursEnd: quietHoursEnd ?? '08:00',
        highContrastMap: highContrastMap == 'true',
        offlineCampusMapsEnabled: offlineCampusMapsEnabled == 'true',
        offlineCampusMapsDownloaded: offlineCampusMapsDownloaded == 'true',
        commuteMode: _normalizeCommuteMode(commuteMode),
        favoriteDirection: favoriteDirection ?? '',
        favoriteRoute: favoriteRoute ?? '',
        favoriteStopId: favoriteStopId ?? '',
        favoriteStopName: favoriteStopName ?? '',
        selectedBachelorId:
            (selectedBachelorId != null && selectedBachelorId.trim().isNotEmpty)
            ? selectedBachelorId
            : null,
        openDayRemindersEnabled: openDayRemindersEnabled != 'false',
        openDayReminderMinutesBefore: _parseMinutes(openDayReminderMinutes),
        showSuggestedStops: showSuggestedStops != 'false',
        savedOpenDayEventIds: _parseSavedEventIds(savedOpenDayEventIds),
        savedStopIds: _parseSavedEventIds(savedStopIds),
        visitedLocationCodes: _parseSavedEventIds(visitedLocationCodes),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load user preferences', error, stackTrace);
      return const UserPreferences();
    }
  }

  @override
  Future<UserPreferences> savePreferences(UserPreferences preferences) async {
    try {
      await _storage.write(_themeModeKey, preferences.themeMode.name);
      if (preferences.localeCode != null) {
        await _storage.write(_localeCodeKey, preferences.localeCode!);
      } else {
        await _storage.delete(_localeCodeKey);
      }
      await _storage.write(
        _notificationsEnabledKey,
        preferences.notificationsEnabled.toString(),
      );
      await _storage.write(
        _defaultTravelModeKey,
        preferences.defaultTravelMode.name,
      );
      await _storage.write(_lowDataModeKey, preferences.lowDataMode.toString());
      await _storage.write(
        _reducedMotionKey,
        preferences.reducedMotion.toString(),
      );
      await _storage.write(
        _hapticsEnabledKey,
        preferences.hapticsEnabled.toString(),
      );
      await _storage.write(
        _quietHoursEnabledKey,
        preferences.quietHoursEnabled.toString(),
      );
      await _storage.write(_quietHoursStartKey, preferences.quietHoursStart);
      await _storage.write(_quietHoursEndKey, preferences.quietHoursEnd);
      await _storage.write(
        _highContrastMapKey,
        preferences.highContrastMap.toString(),
      );
      await _storage.write(
        _offlineCampusMapsEnabledKey,
        preferences.offlineCampusMapsEnabled.toString(),
      );
      await _storage.write(
        _offlineCampusMapsDownloadedKey,
        preferences.offlineCampusMapsDownloaded.toString(),
      );
      await _storage.write(_commuteModeKey, preferences.commuteMode);
      await _storage.write(
        _favoriteDirectionKey,
        preferences.favoriteDirection,
      );
      await _storage.write(_favoriteRouteKey, preferences.favoriteRoute);
      await _storage.write(_favoriteStopIdKey, preferences.favoriteStopId);
      await _storage.write(_favoriteStopNameKey, preferences.favoriteStopName);
      if (preferences.selectedBachelorId != null) {
        await _storage.write(
          _selectedBachelorIdKey,
          preferences.selectedBachelorId!,
        );
      } else {
        await _storage.delete(_selectedBachelorIdKey);
      }
      await _storage.write(
        _openDayRemindersEnabledKey,
        preferences.openDayRemindersEnabled.toString(),
      );
      await _storage.write(
        _openDayReminderMinutesKey,
        preferences.openDayReminderMinutesBefore.toString(),
      );
      await _storage.write(
        _showSuggestedStopsKey,
        preferences.showSuggestedStops.toString(),
      );
      // Stored as a comma-joined string — event IDs never contain commas
      // (they're slug-like, e.g. `evt-comp-1030`), so this is a safe,
      // dependency-free encoding for a small ordered set.
      await _storage.write(
        _savedOpenDayEventIdsKey,
        preferences.savedOpenDayEventIds.join(','),
      );
      await _storage.write(
        _savedStopIdsKey,
        preferences.savedStopIds.join(','),
      );
      await _storage.write(
        _visitedLocationCodesKey,
        preferences.visitedLocationCodes.join(','),
      );
      await _storage.write(
        _hasCompletedOnboardingKey,
        preferences.hasCompletedOnboarding.toString(),
      );
      return preferences;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to save user preferences', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> wipeAllLocalData() async {
    try {
      await _storage.deleteAll();
      AppLogger.info('All local data wiped by user.');
    } catch (e, stack) {
      AppLogger.error('Failed to wipe data', e, stack);
      rethrow;
    }
  }
}

int _parseMinutes(String? raw) {
  final parsed = int.tryParse(raw ?? '');
  if (parsed == null) return 15;
  return parsed.clamp(5, 60);
}

List<String> _parseSavedEventIds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>[];
  return raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

String _normalizeCommuteMode(String? mode) {
  return switch (mode?.trim()) {
    'metro' || 'bus' || 'train' => mode!.trim(),
    _ => 'none',
  };
}
