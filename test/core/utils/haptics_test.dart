import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/core/utils/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invokedTypes = <String>[];

  setUp(() {
    invokedTypes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            invokedTypes.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('MqHaptics', () {
    test('light() invokes the platform channel when enabled', () async {
      await MqHaptics.light(true);
      expect(invokedTypes, ['HapticFeedbackType.lightImpact']);
    });

    test('light() does nothing when disabled', () async {
      await MqHaptics.light(false);
      expect(invokedTypes, isEmpty);
    });

    test('medium() invokes the platform channel when enabled', () async {
      await MqHaptics.medium(true);
      expect(invokedTypes, ['HapticFeedbackType.mediumImpact']);
    });

    test('heavy() invokes the platform channel when enabled', () async {
      await MqHaptics.heavy(true);
      expect(invokedTypes, ['HapticFeedbackType.heavyImpact']);
    });

    test('selection() invokes the platform channel when enabled', () async {
      await MqHaptics.selection(true);
      expect(invokedTypes, ['HapticFeedbackType.selectionClick']);
    });

    test('heavy()/medium()/selection() do nothing when disabled', () async {
      await MqHaptics.medium(false);
      await MqHaptics.heavy(false);
      await MqHaptics.selection(false);
      expect(invokedTypes, isEmpty);
    });
  });
}
