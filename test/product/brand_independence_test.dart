import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/core/config/product_config.dart';

/// Guards Campus Navigation's independence from the university it maps.
///
/// These assert the *public* surface only. Real-world place names (Macquarie
/// Theatre, Macquarie University Station) and legacy technical identifiers
/// (`mq_navigation`, `io.mqnavigation`, `mqnavigation.app`) are explicitly
/// allowed — see docs/BRANDING.md for why each exception exists.
void main() {
  final repo = Directory.current;

  List<File> filesUnder(String dir, Set<String> extensions) {
    final d = Directory('${repo.path}/$dir');
    if (!d.existsSync()) return const [];
    return d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => extensions.any((e) => f.path.endsWith(e)))
        .toList();
  }

  group('no university ownership claims in user-facing strings', () {
    // Two real-world proper nouns the app legitimately displays: a suburb in a
    // postal address, and the name of a Metro station.
    const allowedKeys = {'calendarJsonLdLocationAddress', 'favoriteStopIdHint'};

    test('localisation files carry no university branding', () {
      final offenders = <String>[];
      for (final file in filesUnder('lib/app/l10n', {'.arb'})) {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        json.forEach((key, value) {
          if (key.startsWith('@') || value is! String) return;
          if (allowedKeys.contains(key)) return;
          if (RegExp(
            'macquarie|麦考瑞|ماكواري|мaккуори|マッコーリー|맥쿼리',
            caseSensitive: false,
          ).hasMatch(value)) {
            offenders.add('${file.uri.pathSegments.last}:$key = $value');
          }
          if (RegExp(r'(?<![A-Za-z0-9])MQ(?![A-Za-z0-9])').hasMatch(value)) {
            offenders.add('${file.uri.pathSegments.last}:$key = $value');
          }
        });
      }
      expect(offenders, isEmpty, reason: offenders.take(8).join('\n'));
    });

    test('no "official app" or university-publisher language', () {
      final offenders = <String>[];
      for (final file in filesUnder('lib/app/l10n', {'.arb'})) {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        json.forEach((key, value) {
          if (key.startsWith('@') || value is! String) return;
          if (RegExp(
            r'official (university )?app|university[- ]owned|published by the university',
            caseSensitive: false,
          ).hasMatch(value)) {
            offenders.add('${file.uri.pathSegments.last}:$key = $value');
          }
        });
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  test('no university logo ships in the bundle', () {
    final logos = filesUnder('assets/images', {'.png', '.jpg'})
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.contains('mq_logo') || n.contains('university'))
        .toList();
    expect(logos, isEmpty, reason: 'university crest found: $logos');
  });

  test('copyright names the team and credits name the developers', () {
    // Rights sit with the team identity; the two authors are credited
    // separately by name on the About screen.
    expect(ProductConfig.copyright, contains('Perky Coders'));
    expect(ProductConfig.copyright, contains('2026'));
    expect(ProductConfig.developersLine, contains('Leo Alavi'));
    expect(ProductConfig.developersLine, contains('Mohammad Raouf Abedini'));
    expect(ProductConfig.copyright.toLowerCase(), isNot(contains('macquarie')));
    expect(
      ProductConfig.copyright.toLowerCase(),
      isNot(contains('university')),
    );
    expect(ProductConfig.supportEmail, isNot(contains('mq.edu.au')));
    expect(ProductConfig.supportEmail, 'leo@leoalavi.dev');
  });

  test('retired support address is absent from public product files', () {
    final offenders = <String>[];
    for (final file in [
      ...filesUnder('lib', {'.dart', '.arb'}),
      ...filesUnder('docs', {'.md'}),
    ]) {
      if (file.readAsStringSync().contains('support@campusnavigation.app')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('no authentication surface', () {
    test('the auth feature is gone', () {
      expect(Directory('${repo.path}/lib/features/auth').existsSync(), isFalse);
    });

    test('no sign-in/sign-out routes or calls remain in source', () {
      final offenders = <String>[];
      for (final file in filesUnder('lib', {'.dart'})) {
        if (file.path.contains('l10n/generated')) continue;
        final text = file.readAsStringSync();
        for (final pattern in const [
          'signInWithPassword',
          'signOut(',
          "'/auth/login'",
          "'/auth/signup'",
          'authControllerProvider',
          'authRepositoryProvider',
        ]) {
          if (text.contains(pattern)) {
            offenders.add('${file.path.split('/lib/').last}: $pattern');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('Android + iOS only', () {
    // Web is deliberately kept BUILDABLE so CI can compile and test it, but
    // it is never released: the shipped product is Android + iOS. So the
    // guard is on what the build *claims*, not on whether it exists.
    test('the web build does not present itself as a product', () {
      final indexFile = File('${repo.path}/web/index.html');
      if (!indexFile.existsSync()) return; // web scaffolding is optional
      final index = indexFile.readAsStringSync();
      expect(
        index,
        contains('noindex'),
        reason: 'the CI web build must not be indexable',
      );
      expect(index, contains('Campus Navigation'));

      final manifest =
          jsonDecode(
                File('${repo.path}/web/manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(manifest['name'], 'Campus Navigation');
      expect(
        (manifest['description'] as String).toLowerCase(),
        anyOf(contains('development'), contains('ci')),
        reason: 'the manifest should mark this as a non-released build',
      );
    });

    test('nothing advertises a Campus Navigation web app', () {
      final offenders = <String>[];
      for (final file in filesUnder('lib/app/l10n', {'.arb'})) {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        json.forEach((key, value) {
          if (value is! String) return;
          if (RegExp(
            r'web app|web version|open in (your )?browser',
            caseSensitive: false,
          ).hasMatch(value)) {
            offenders.add('${file.uri.pathSegments.last}:$key = $value');
          }
        });
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  test('no Astronomy Open Night event branding', () {
    final offenders = <String>[];
    for (final file in [
      ...filesUnder('lib', {'.dart', '.arb'}),
      ...filesUnder('assets/data', {'.json'}),
    ]) {
      final text = file.readAsStringSync().toLowerCase();
      for (final term in const [
        'astronomy open night',
        'open night',
        'astronomy passport',
        'solar system walk',
      ]) {
        if (text.contains(term)) offenders.add('${file.path}: $term');
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(5).join('\n'));
  });

  test('Syllabus Sync logo is referenced only by the About row', () {
    final references = <String>[];
    for (final file in filesUnder('lib', {'.dart'})) {
      final text = file.readAsStringSync();
      if (text.contains('assets/images/syllabus_sync_logo.png')) {
        references.add(file.path);
      }
    }
    expect(references, hasLength(1));
    expect(references.single, endsWith('settings_page.dart'));
    expect(ProductConfig.appName, 'Campus Navigation');
  });

  test(
    'Campus Navigation primary identity is unaffected by the ecosystem row',
    () {
      // The Home hero carries no logo at all now — the app mark identifies
      // the product on the launcher and the store, not above copy that
      // already names it. Critically it must never be the Syllabus Sync mark.
      final home = File(
        '${repo.path}/lib/features/home/presentation/pages/home_page.dart',
      ).readAsStringSync();
      expect(home, isNot(contains('syllabus_sync_logo')));
      expect(
        home,
        isNot(contains('app_logo.png')),
        reason: 'Home hero should render no logo',
      );

      final pubspec = File('${repo.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('image_path: "assets/images/app_logo.png"'));

      // Splash / launch screen also stays on Campus Navigation's own asset.
      expect(
        File('${repo.path}/lib/app/mq_navigation_app.dart').readAsStringSync(),
        isNot(contains('syllabus_sync_logo')),
      );
    },
  );
}
