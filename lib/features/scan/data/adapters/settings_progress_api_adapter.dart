import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_navigation/features/scan/domain/contracts/progress_api.dart';
import 'package:campus_navigation/features/scan/domain/contracts/visit_event.dart';
import 'package:campus_navigation/features/scan/domain/contracts/visited_state.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:campus_navigation/shared/models/user_preferences.dart';

/// Stamps and visits live on the device only. Campus Navigation has no
/// accounts, so there is no anonymous Supabase session to sync them against.
class SettingsProgressApiAdapter implements ProgressApi {
  SettingsProgressApiAdapter(this._ref);
  final Ref _ref;

  @override
  Future<bool> recordVisit(VisitEvent event) async {
    var isNewVisit = false;
    if (event.buildingId != null) {
      isNewVisit = await _ref
          .read(settingsControllerProvider.notifier)
          .recordLocationVisit(event.buildingId!);
    }
    return isNewVisit;
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
