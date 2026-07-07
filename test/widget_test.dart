import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';

void main() {
  group('MqColors', () {
    test('brand accent is the Open Day 2026 magenta', () {
      expect(MqColors.red, const Color(0xFFC6006F));
    });

    test('alabaster matches web token', () {
      expect(MqColors.alabaster, const Color(0xFFEDEADE));
    });
  });

  group('MqSpacing', () {
    test('minimum tap target is 48dp', () {
      expect(MqSpacing.minTapTarget, 48);
    });

    test('space4 is 16', () {
      expect(MqSpacing.space4, 16);
    });
  });
}
