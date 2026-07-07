import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/features/map/domain/entities/route_leg.dart';
import 'package:mq_journey/features/notifications/domain/entities/app_notification.dart';
import 'package:mq_journey/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_journey/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, UserPreferences>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() {
    return ref.read(settingsRepositoryProvider).loadPreferences();
  }

  Future<String?> updateThemeMode(ThemeMode themeMode) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(themeMode: themeMode));
  }

  Future<String?> updateLocaleCode(String? localeCode) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(
      currentPreferences.copyWith(
        localeCode: localeCode,
        clearLocale: localeCode == null,
      ),
    );
  }

  Future<String?> updateNotificationsEnabled(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    final result = await _save(
      currentPreferences.copyWith(notificationsEnabled: enabled),
    );
    try {
      final notifier = ref.read(notificationsControllerProvider.notifier);
      for (final type in NotificationType.values) {
        await notifier.updatePreference(type, enabled);
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to sync notification preferences',
        error,
        stackTrace,
      );
    }
    return result;
  }

  Future<String?> updateLowDataMode(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(lowDataMode: enabled));
  }

  Future<String?> updateReducedMotion(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(reducedMotion: enabled));
  }

  Future<String?> updateHapticsEnabled(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(hapticsEnabled: enabled));
  }

  Future<String?> updateQuietHoursEnabled(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(quietHoursEnabled: enabled));
  }

  Future<String?> updateQuietHoursStart(String time) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(quietHoursStart: time));
  }

  Future<String?> updateQuietHoursEnd(String time) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(quietHoursEnd: time));
  }

  Future<String?> updateHighContrastMap(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(highContrastMap: enabled));
  }

  Future<String?> updateOfflineCampusMapsEnabled(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(
      currentPreferences.copyWith(offlineCampusMapsEnabled: enabled),
    );
  }

  Future<String?> updateOfflineCampusMapsDownloaded(bool downloaded) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(
      currentPreferences.copyWith(offlineCampusMapsDownloaded: downloaded),
    );
  }

  Future<String?> updateCommutePreferences({
    String? commuteMode,
    String? favoriteDirection,
    String? favoriteRoute,
    String? favoriteStopId,
    String? favoriteStopName,
  }) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(
      currentPreferences.copyWith(
        commuteMode: commuteMode == null
            ? null
            : _normalizeCommuteMode(commuteMode),
        favoriteDirection: favoriteDirection,
        favoriteRoute: favoriteRoute,
        favoriteStopId: favoriteStopId,
        favoriteStopName: favoriteStopName,
      ),
    );
  }

  Future<String?> updateOpenDayRemindersEnabled(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(openDayRemindersEnabled: enabled));
  }

  Future<String?> updateOpenDayReminderMinutesBefore(int minutes) async {
    final clamped = minutes.clamp(5, 60);
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(
      currentPreferences.copyWith(openDayReminderMinutesBefore: clamped),
    );
  }

  Future<String?> updateShowSuggestedStops(bool enabled) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(showSuggestedStops: enabled));
  }

  /// Adds or removes an event from the user's saved "Your Day" itinerary.
  /// Toggle semantics keep the call site (a single bookmark button) trivial.
  Future<String?> toggleSavedOpenDayEvent(String eventId) async {
    final currentPreferences = state.value ?? const UserPreferences();
    final current = currentPreferences.savedOpenDayEventIds;
    final updated = current.contains(eventId)
        ? (current.where((id) => id != eventId).toList(growable: false))
        : ([...current, eventId]);
    return _save(currentPreferences.copyWith(savedOpenDayEventIds: updated));
  }

  Future<String?> clearSavedOpenDayEvents() async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(
      currentPreferences.copyWith(
        savedOpenDayEventIds: const <String>[],
        savedStopIds: const <String>[],
      ),
    );
  }

  /// Adds or removes a suggested stop from "Your Day".
  Future<String?> toggleSavedStop(String stopId) async {
    final currentPreferences = state.value ?? const UserPreferences();
    final current = currentPreferences.savedStopIds;
    final updated = current.contains(stopId)
        ? (current.where((id) => id != stopId).toList(growable: false))
        : ([...current, stopId]);
    return _save(currentPreferences.copyWith(savedStopIds: updated));
  }

  /// Records a visit to a location (e.g. from a QR scan). Idempotent: a
  /// repeat visit to the same building is a no-op, so the gamification layer
  /// never awards duplicate XP. Returns `true` when this was a *new* visit
  /// (so the caller can show a first-visit reward), `false` otherwise.
  Future<bool> recordLocationVisit(String buildingCode) async {
    final code = buildingCode.trim().toUpperCase();
    if (code.isEmpty) return false;
    final currentPreferences = state.value ?? const UserPreferences();
    if (currentPreferences.visitedLocationCodes.contains(code)) {
      return false;
    }
    await _save(
      currentPreferences.copyWith(
        visitedLocationCodes: [
          ...currentPreferences.visitedLocationCodes,
          code,
        ],
      ),
    );
    return true;
  }

  Future<String?> updateSelectedBachelorId(String? bachelorId) async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(
      currentPreferences.copyWith(
        selectedBachelorId: bachelorId,
        clearSelectedBachelor: bachelorId == null,
      ),
    );
  }

  Future<String?> completeOnboarding() async {
    final currentPreferences = state.value ?? const UserPreferences();
    return _save(currentPreferences.copyWith(hasCompletedOnboarding: true));
  }

  Future<String?> wipeAllLocalData() async {
    try {
      await ref.read(settingsRepositoryProvider).wipeAllLocalData();
      state = AsyncData(await build());
      return null;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to wipe data', error, stackTrace);
      return 'Unable to wipe data.';
    }
  }

  Future<String?> _save(UserPreferences preferences) async {
    final previous = state.value;
    try {
      state = AsyncData(preferences);
      final saved = await ref
          .read(settingsRepositoryProvider)
          .savePreferences(preferences);
      state = AsyncData(saved);
      return null;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to persist settings', error, stackTrace);
      if (previous != null) {
        state = AsyncData(previous);
      }
      return _saveErrorMessage;
    }
  }

  static const _saveErrorMessage = 'Unable to save settings.';

  static String _normalizeCommuteMode(String mode) {
    return switch (mode.trim()) {
      'metro' || 'bus' || 'train' => mode.trim(),
      _ => 'none',
    };
  }
}
