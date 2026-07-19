import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/features/scan/domain/contracts/progress_api.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/models/user_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> ensureAnonSession({SupabaseClient? supabaseClient}) async {
  final supabase = supabaseClient ?? Supabase.instance.client;
  if (supabase.auth.currentUser != null) return;
  await supabase.auth.signInAnonymously();
}

class SettingsProgressApiAdapter implements ProgressApi {
  SettingsProgressApiAdapter(this._ref, {SupabaseClient? supabaseClient})
    : _supabaseClientOverride = supabaseClient;
  final Ref _ref;
  final SupabaseClient? _supabaseClientOverride;
  late final SupabaseClient _supabaseClient =
      _supabaseClientOverride ?? Supabase.instance.client;

  @override
  Future<bool> recordVisit(VisitEvent event) async {
    // Record the visit LOCALLY first — local storage is the source of truth
    // for stamps and Your Day. Previously this awaited a network anon-session
    // sign-in before recording; on a weak Open Day connection that throw
    // aborted the whole record, so stamps never filled. Local recording must
    // never depend on the network.
    var isNewVisit = false;
    if (event.buildingId != null) {
      isNewVisit = await _ref
          .read(settingsControllerProvider.notifier)
          .recordLocationVisit(event.buildingId!);
    }

    // Best-effort remote sync — must never block or fail the local award.
    if (isNewVisit) {
      unawaited(_syncRemoteStamp(event.locationId));
    }

    return isNewVisit;
  }

  Future<void> _syncRemoteStamp(String locationId) async {
    try {
      await ensureAnonSession(supabaseClient: _supabaseClient);
      await _enqueueStampUpsert(locationId);
    } catch (e, s) {
      AppLogger.warning('Remote stamp sync skipped (offline?)', e, s);
    }
  }

  Future<void> _enqueueStampUpsert(String locationId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return;
      await _supabaseClient
          .from('open_day_stamps')
          .upsert(
            {
              'user_id': userId,
              'location_id': locationId,
              'scanned_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id,location_id',
            ignoreDuplicates: true,
          );
    } catch (e, s) {
      AppLogger.warning('Failed to upsert stamp', e, s);
    }
  }

  @override
  Stream<VisitedState> watch(String locationId) {
    final normalizedLocationId = locationId.trim().toUpperCase();
    late final StreamController<VisitedState> controller;
    late final ProviderSubscription<AsyncValue<UserPreferences>>
    settingsSubscription;

    void emit() {
      if (controller.isClosed) return;
      final prefs = _ref.read(settingsControllerProvider).value;
      final codes = prefs?.visitedLocationCodes ?? const <String>[];
      controller.add(
        VisitedState(
          visited: codes
              .map((code) => code.trim().toUpperCase())
              .contains(normalizedLocationId),
          rewardEarned: false,
        ),
      );
    }

    controller = StreamController<VisitedState>.broadcast(
      onListen: emit,
      onCancel: () {
        settingsSubscription.close();
        unawaited(controller.close());
      },
    );
    settingsSubscription = _ref.listen(
      settingsControllerProvider,
      (_, _) => emit(),
    );

    return controller.stream;
  }
}

final progressApiProvider = Provider<ProgressApi>((ref) {
  return SettingsProgressApiAdapter(ref);
});
