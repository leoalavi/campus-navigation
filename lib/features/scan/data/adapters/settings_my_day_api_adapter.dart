import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_navigation/features/scan/domain/contracts/my_day_api.dart';
import 'package:campus_navigation/features/scan/domain/contracts/my_day_entry.dart';
import 'package:campus_navigation/features/settings/presentation/controllers/settings_controller.dart';

class SettingsMyDayApiAdapter implements MyDayApi {
  SettingsMyDayApiAdapter(this._ref);
  final Ref _ref;

  @override
  Future<void> addToDay(MyDayEntry entry) async {
    await _ref
        .read(settingsControllerProvider.notifier)
        .toggleSavedStop(entry.locationId);
  }
}
