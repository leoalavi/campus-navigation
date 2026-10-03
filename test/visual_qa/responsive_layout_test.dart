import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:campus_navigation/app/l10n/generated/app_localizations.dart';
import 'package:campus_navigation/app/startup_screen.dart';
import 'package:campus_navigation/app/theme/mq_theme.dart';
import 'package:campus_navigation/features/home/presentation/pages/home_page.dart';
import 'package:campus_navigation/features/home/presentation/pages/onboarding_page.dart';
import 'package:campus_navigation/features/map/data/services/offline_maps_service.dart';
import 'package:campus_navigation/features/map/domain/entities/map_renderer_type.dart';
import 'package:campus_navigation/features/map/presentation/widgets/map_shell.dart';
import 'package:campus_navigation/features/notifications/data/datasources/fcm_service.dart';
import 'package:campus_navigation/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:campus_navigation/features/open_day/data/open_day_providers.dart';
import 'package:campus_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:campus_navigation/features/open_day/presentation/widgets/open_day_home_card.dart';
import 'package:campus_navigation/features/settings/data/repositories/settings_repository.dart';
import 'package:campus_navigation/features/settings/presentation/pages/settings_page.dart';
import 'package:campus_navigation/features/transit/presentation/providers/tfnsw_provider.dart';
import 'package:campus_navigation/shared/models/user_preferences.dart';

/// Responsive layout sweep: renders the main surfaces at the device sizes we
/// ship to (small iPhone → tablet) and with enlarged text, failing on any
/// layout exception — including the yellow/black RenderFlex overflow stripe.
///
/// Set `QA_SHOTS=<dir>` to also write PNG screenshots (with real Roboto +
/// Material Icons) for manual review:
///   QA_SHOTS=/tmp/qa flutter test test/visual_qa
class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockOfflineMapsService extends Mock implements OfflineMapsService {}

class _FakeNotificationsController extends NotificationsController {
  @override
  Future<NotificationsState> build() async => const NotificationsState(
    permissionStatus: NotificationPermissionStatus.granted,
    preferences: [],
  );
}

const _viewports = <(String, Size)>[
  ('iphone-se', Size(320, 568)),
  ('iphone-15', Size(393, 852)),
  ('android', Size(412, 915)),
  ('large-phone', Size(430, 932)),
  ('tablet', Size(820, 1180)),
];

final _shotsDir = Platform.environment['QA_SHOTS'];

OpenDayData? _openDayData;

/// Measure with the real platform font (Roboto) rather than the test font,
/// whose square glyphs make every string far wider than on a device and
/// would report overflows that cannot happen. Resolved from the Flutter SDK
/// running the test, so it works locally and in CI.
Future<void> _loadRealFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final root = '$flutterRoot/bin/cache/artifacts/material_fonts';
  if (!Directory(root).existsSync()) return;
  Future<ByteData> read(String f) async =>
      ByteData.sublistView(await File('$root/$f').readAsBytes());
  // 'FlutterTest' is what a TextStyle with no family resolves to in tests;
  // on a device the same style gets the platform font. Map both to Roboto.
  for (final family in const ['Roboto', 'FlutterTest']) {
    final loader = FontLoader(family);
    for (final w in const [
      'Thin',
      'Light',
      'Regular',
      'Medium',
      'Bold',
      'Black',
    ]) {
      loader.addFont(read('Roboto-$w.ttf'));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

final _shotKey = GlobalKey();

Future<void> _shoot(WidgetTester tester, String name) async {
  final dir = _shotsDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$name.png')..createSync(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(
  Widget child, {
  required double textScale,
  List overrides = const [],
  bool router = false,
}) {
  final app = router
      ? MaterialApp.router(
          theme: MqTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => child),
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (_, _) => const SizedBox(),
              ),
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (_, _) => const SizedBox(),
              ),
            ],
          ),
          builder: (context, c) => _scaled(context, c!, textScale),
        )
      : MaterialApp(
          theme: MqTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, c) => _scaled(context, c!, textScale),
          home: child,
        );
  return ProviderScope(
    overrides: [...overrides],
    child: RepaintBoundary(key: _shotKey, child: app),
  );
}

Widget _scaled(BuildContext context, Widget child, double scale) => MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.linear(scale),
    padding: const EdgeInsets.only(top: 47, bottom: 34),
    viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
  ),
  child: child,
);

List _appOverrides({required bool openDay, DateTime? now}) {
  final repo = _MockSettingsRepository();
  when(repo.loadPreferences).thenAnswer(
    (_) async => UserPreferences(
      hasCompletedOnboarding: true,
      openDayEnabled: openDay,
      selectedBachelorId: openDay ? 'it' : null,
      commuteMode: 'metro',
    ),
  );
  when(
    () => repo.savePreferences(any()),
  ).thenAnswer((i) async => i.positionalArguments[0] as UserPreferences);
  final offline = _MockOfflineMapsService();
  when(() => offline.isFmtcBackendReady).thenReturn(false);
  return [
    settingsRepositoryProvider.overrideWithValue(repo),
    offlineMapsServiceProvider.overrideWithValue(offline),
    notificationsControllerProvider.overrideWith(
      _FakeNotificationsController.new,
    ),
    tfnswMetroProvider.overrideWith((ref) => Stream.value(const [])),
    openDayNowProvider.overrideWithValue(now ?? DateTime(2026, 8, 15, 9, 30)),
    // The real bundled dataset, parsed up front: asset loading doesn't
    // complete inside a widget-test frame, which would hide every Open Day
    // card and leave the opted-in layout unreviewed.
    openDayDataProvider.overrideWith((ref) async => _openDayData!),
  ];
}

void main() {
  setUpAll(() async {
    registerFallbackValue(const UserPreferences());
    // The app does this in bootstrap(); Open Day times are Sydney-local.
    tz.initializeTimeZones();
    _openDayData = OpenDayData.fromJson(
      jsonDecode(File('assets/data/open_day.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await _loadRealFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (device, size) in _viewports) {
    for (final scale in const [1.0, 1.3]) {
      final tag = '$device@${scale}x';

      testWidgets('startup screen – $tag', (tester) async {
        _setViewport(tester, size);
        await tester.pumpWidget(_wrap(const StartupScreen(), textScale: scale));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        // Icon is exactly centred, matching the native launch screen.
        final icon = tester.getCenter(find.byType(Image).first);
        expect(icon.dx, closeTo(size.width / 2, 0.5));
        expect(icon.dy, closeTo(size.height / 2, 0.5));
        await _shoot(tester, 'startup_$tag');
      });

      testWidgets('onboarding – $tag', (tester) async {
        _setViewport(tester, size);
        await tester.pumpWidget(
          _wrap(
            const OnboardingPage(),
            textScale: scale,
            router: true,
            overrides: _appOverrides(openDay: false),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(OnboardingPage)),
        )!;
        for (var i = 0; i < 3; i++) {
          expect(tester.takeException(), isNull, reason: 'slide $i');
          await _shoot(tester, 'onboarding_${i + 1}_$tag');
          if (i < 2) {
            await tester.tap(find.text(l10n.onboardingNext));
            await tester.pumpAndSettle();
          }
        }
      });

      for (final openDay in const [false, true]) {
        final od = openDay ? 'openday' : 'core';
        testWidgets('home ($od) – $tag', (tester) async {
          _setViewport(tester, size);
          await tester.pumpWidget(
            _wrap(
              const HomePage(),
              textScale: scale,
              router: true,
              overrides: _appOverrides(openDay: openDay),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Open Day content is present only when the user opted in.
          expect(
            find.byType(OpenDayHomeCard, skipOffstage: false),
            openDay ? findsOneWidget : findsNothing,
          );
          await _shoot(tester, 'home_${od}_$tag');
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -900),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _shoot(tester, 'home_${od}_scrolled_$tag');
        });

        testWidgets('settings ($od) – $tag', (tester) async {
          _setViewport(tester, size);
          await tester.pumpWidget(
            _wrap(
              const SettingsPage(),
              textScale: scale,
              router: true,
              overrides: _appOverrides(openDay: openDay),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _shoot(tester, 'settings_${od}_top_$tag');
          // Walk the whole page so every section is laid out at least once.
          final scrollable = find.byType(Scrollable).first;
          for (var page = 1; page <= 12; page++) {
            await tester.drag(scrollable, Offset(0, -size.height * 0.8));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'page $page');
          }
          await _shoot(tester, 'settings_${od}_bottom_$tag');
        });
      }

      testWidgets('home (openday, after the event) – $tag', (tester) async {
        _setViewport(tester, size);
        await tester.pumpWidget(
          _wrap(
            const HomePage(),
            textScale: scale,
            router: true,
            overrides: _appOverrides(openDay: true, now: DateTime(2027, 8, 16)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('open-day-finished-card')),
          findsOneWidget,
        );
        await _shoot(tester, 'home_openday_finished_$tag');
      });

      testWidgets('map shell with category sheet – $tag', (tester) async {
        _setViewport(tester, size);
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: MapShell(
                mapView: const ColoredBox(color: Color(0xFFE8E4D8)),
                renderer: MapRendererType.campus,
                onRendererChanged: (_) {},
                onCenterOnLocation: () {},
                onOpenSearch: () {},
                onOpenOverlayPicker: () {},
                footer: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const ListTile(title: Text('Student Services')),
                    for (final s in const [
                      'Support & Wellbeing',
                      'Administration & Enquiries',
                      'Academic Help & Learning Support',
                      'Careers & Employment',
                      'IT & Library Services',
                    ])
                      ListTile(
                        leading: const Icon(Icons.support_agent),
                        title: Text(s),
                        subtitle: const Text('Counselling, welfare, …'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                  ],
                ),
              ),
            ),
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _shoot(tester, 'map_sheet_$tag');
      });
    }
  }
}
