import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/router/shell_chrome_provider.dart';
import 'package:mq_navigation/features/open_day/data/open_day_providers.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_navigation/features/open_day/presentation/widgets/bachelor_picker_sheet.dart';

/// Enough programmes to overflow any phone viewport, which is the condition
/// that produced "BOTTOM OVERFLOWED BY 11 PIXELS".
OpenDayData _bulkData() => OpenDayData(
  openDayDate: DateTime(2027, 8, 14),
  lastUpdated: DateTime(2027),
  studyAreas: const [
    OpenDayStudyArea(id: 'sci', name: 'Science & Engineering', icon: 'science'),
    OpenDayStudyArea(
      id: 'med',
      name: 'Medicine, Health & Human Sciences',
      icon: 'medical_services',
    ),
  ],
  bachelors: [
    for (var i = 0; i < 14; i++)
      OpenDayBachelor(
        id: 'sci-$i',
        name: 'Bachelor of Very Long Programme Name Number $i',
        studyAreaId: 'sci',
      ),
    for (var i = 0; i < 14; i++)
      OpenDayBachelor(
        id: 'med-$i',
        name: 'Bachelor of Another Lengthy Programme Title $i',
        studyAreaId: 'med',
      ),
  ],
  events: const [],
);

void main() {
  Widget harness({required Widget home}) => ProviderScope(
    overrides: [openDayDataProvider.overrideWith((ref) async => _bulkData())],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  /// Opens the sheet from a button, the way the app does.
  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => BachelorPickerSheet.show(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(640, 360), // short/landscape window — where the 11px overflow appeared
    Size(320, 568), // iPhone SE (1st gen) — tightest supported
    Size(375, 667), // iPhone SE (2nd/3rd gen)
    Size(390, 844), // iPhone 14/15
    Size(360, 640), // common small Android
    Size(834, 1112), // tablet
  ]) {
    testWidgets('picker does not overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await openPicker(tester);

      // A RenderFlex overflow surfaces as a thrown FlutterError here.
      expect(tester.takeException(), isNull);
      expect(find.byType(BachelorPickerSheet), findsOneWidget);

      // Structural invariant behind the "BOTTOM OVERFLOWED BY 11 PIXELS"
      // banner: the sheet plus its own chrome must fit the viewport. Asserted
      // directly because a RenderFlex overflow only *throws* when the excess
      // lands in a Flex — clipping elsewhere is silent.
      final sheet = tester.getRect(find.byType(BachelorPickerSheet));
      expect(
        sheet.height,
        lessThanOrEqualTo(size.height + 0.5),
        reason: 'sheet is taller than the screen',
      );
      expect(sheet.bottom, lessThanOrEqualTo(size.height + 0.5));
    });
  }

  // Devices with a notch + home indicator are where the original overflow was
  // reported; test viewports have no insets unless they are set explicitly.
  testWidgets('picker fits a viewport with notch and home-indicator insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await openPicker(tester);

    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(find.byType(BachelorPickerSheet));
    expect(sheet.bottom, lessThanOrEqualTo(844 + 0.5));
  });

  testWidgets('picker fits when the keyboard claims the bottom half', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await openPicker(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('long programme list stays scrollable rather than clipping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await openPicker(tester);

    expect(find.byType(Scrollable), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom nav is hidden while the picker is open', (tester) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      harness(
        home: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => BachelorPickerSheet.show(context, ref),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(capturedRef.read(bottomNavVisibleProvider), isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(capturedRef.read(bottomNavVisibleProvider), isFalse);

    // Dismiss the sheet the way a user would.
    Navigator.of(tester.element(find.byType(BachelorPickerSheet))).pop();
    await tester.pumpAndSettle();
    expect(capturedRef.read(bottomNavVisibleProvider), isTrue);
  });
}
