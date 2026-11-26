import 'package:campus_navigation/app/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('onboardingLocationFor', () {
    test('keeps a deep link through onboarding', () {
      expect(
        Uri.parse(
          onboardingLocationFor(
            Uri.parse('/open?destination=C5C&action=directions'),
          ),
        ).queryParameters['next'],
        '/open?destination=C5C&action=directions',
      );
    });

    test('plain onboarding for the home screen', () {
      expect(onboardingLocationFor(Uri.parse('/home')), '/onboarding');
      expect(onboardingLocationFor(Uri.parse('/')), '/onboarding');
    });
  });

  group('safeOnboardingNext', () {
    test('accepts internal paths only', () {
      expect(
        safeOnboardingNext('/open?destination=C5C'),
        '/open?destination=C5C',
      );
      expect(safeOnboardingNext('https://evil.example'), isNull);
      expect(safeOnboardingNext('//evil.example'), isNull);
      expect(safeOnboardingNext('/onboarding?next=/x'), isNull);
      expect(safeOnboardingNext(null), isNull);
      expect(safeOnboardingNext(''), isNull);
    });
  });
}
