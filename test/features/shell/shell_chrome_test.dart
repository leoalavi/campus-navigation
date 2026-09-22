import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_navigation/app/router/shell_chrome_provider.dart';

/// The bottom navigation must retract while a focused surface (Open Day
/// picker, map category sheet) is up, and come back exactly once — see
/// `AppShell`, which drives its slide/fade off [bottomNavVisibleProvider].
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('nav is visible by default', () {
    expect(container.read(bottomNavVisibleProvider), isTrue);
  });

  test('a modal sheet hides the nav and restores it on close', () {
    final chrome = container.read(shellChromeProvider.notifier);

    chrome.acquire();
    expect(container.read(bottomNavVisibleProvider), isFalse);

    chrome.release();
    expect(container.read(bottomNavVisibleProvider), isTrue);
  });

  // Sheets legitimately stack (a map category sheet opening a building sheet
  // on top). Closing the inner one must not restore the nav under the outer.
  test('nested sheets only restore the nav when the last one closes', () {
    final chrome = container.read(shellChromeProvider.notifier);

    chrome.acquire();
    chrome.acquire();
    chrome.release();
    expect(container.read(bottomNavVisibleProvider), isFalse);

    chrome.release();
    expect(container.read(bottomNavVisibleProvider), isTrue);
  });

  test('a stray double-release cannot strand the nav hidden', () {
    final chrome = container.read(shellChromeProvider.notifier);

    chrome.acquire();
    chrome.release();
    chrome.release(); // would drive the counter negative if unclamped
    expect(container.read(shellChromeProvider), 0);

    chrome.acquire();
    expect(container.read(bottomNavVisibleProvider), isFalse);
  });

  test('guard releases even when the guarded future throws', () async {
    final chrome = container.read(shellChromeProvider.notifier);

    await expectLater(
      chrome.guard(Future<void>.error(StateError('dismissed'))),
      throwsStateError,
    );
    expect(container.read(bottomNavVisibleProvider), isTrue);
  });

  test('an open map sheet hides the nav independently of modal sheets', () {
    container.read(mapSheetOpenProvider.notifier).set(true);
    expect(container.read(bottomNavVisibleProvider), isFalse);

    container.read(mapSheetOpenProvider.notifier).set(false);
    expect(container.read(bottomNavVisibleProvider), isTrue);
  });
}
