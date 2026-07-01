import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/core/logging/app_logger.dart';
import 'package:mq_journey/features/scan/domain/contracts/progress_api.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
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
    // ignore: close_sinks
    final controller = StreamController<VisitedState>.broadcast();

    void emit() {
      final prefs = _ref.read(settingsControllerProvider).value;
      final codes = prefs?.visitedLocationCodes ?? const <String>[];
      controller.add(
        VisitedState(visited: codes.contains(locationId), rewardEarned: false),
      );
    }

    emit();
    _ref.listen(settingsControllerProvider, (_, _) => emit());

    return controller.stream;
  }
}

final progressApiProvider = Provider<ProgressApi>((ref) {
  return SettingsProgressApiAdapter(ref);
});
