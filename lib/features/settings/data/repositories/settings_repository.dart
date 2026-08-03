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
      final values = await _storage.readAll();
      final themeModeString = values[_themeModeKey];
      final localeCode = values[_localeCodeKey];
      final notificationsEnabled = values[_notificationsEnabledKey];
      final defaultTravelModeString = values[_defaultTravelModeKey];
      final lowDataMode = values[_lowDataModeKey];
      final reducedMotion = values[_reducedMotionKey];
      final hapticsEnabled = values[_hapticsEnabledKey];
      final quietHoursEnabled = values[_quietHoursEnabledKey];
      final quietHoursStart = values[_quietHoursStartKey];
      final quietHoursEnd = values[_quietHoursEndKey];
      final highContrastMap = values[_highContrastMapKey];
      final commuteMode = values[_commuteModeKey];
      final favoriteDirection = values[_favoriteDirectionKey];
      final favoriteRoute = values[_favoriteRouteKey];
      final favoriteStopId = values[_favoriteStopIdKey];
      final favoriteStopName = values[_favoriteStopNameKey];
      final selectedBachelorId = values[_selectedBachelorIdKey];
      final openDayRemindersEnabled = values[_openDayRemindersEnabledKey];
      final openDayReminderMinutes = values[_openDayReminderMinutesKey];
      final showSuggestedStops = values[_showSuggestedStopsKey];
      final savedOpenDayEventIds = values[_savedOpenDayEventIdsKey];
      final savedStopIds = values[_savedStopIdsKey];
      final visitedLocationCodes = values[_visitedLocationCodesKey];
      final hasCompletedOnboarding = values[_hasCompletedOnboardingKey];

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
