import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/core/network/connectivity_service.dart';

const _methodChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _eventChannel = MethodChannel(
  'dev.fluttercommunity.plus/connectivity_status',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 'check' → the initial connectivity snapshot.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          if (call.method == 'check') {
            return <String>['wifi'];
          }
          return null;
        });
    // The event channel's "listen"/"cancel" handshake — no events fired,
    // just needs to not throw so the constructor's subscription succeeds.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_eventChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_eventChannel, null);
  });

  test('check() reports online when a real connection is present', () async {
    final service = ConnectivityService();
    addTearDown(service.dispose);

    final status = await service.check();

    expect(status, ConnectivityStatus.online);
    expect(service.status, ConnectivityStatus.online);
  });

  test('check() reports offline when the platform reports none', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          if (call.method == 'check') {
            return <String>['none'];
          }
          return null;
        });

    final service = ConnectivityService();
    addTearDown(service.dispose);

    final status = await service.check();

    expect(status, ConnectivityStatus.offline);
  });

  test('stream only emits when the status actually changes', () async {
    final service = ConnectivityService();
    addTearDown(service.dispose);

    final emitted = <ConnectivityStatus>[];
    final sub = service.stream.listen(emitted.add);
    addTearDown(sub.cancel);

    // First check: still 'wifi' (online) → status unchanged from the
    // default → no emission.
    await service.check();
    expect(emitted, isEmpty);

    // Now flip the mocked platform result to offline and check again.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          if (call.method == 'check') {
            return <String>['none'];
          }
          return null;
        });
    await service.check();
    await service.check(); // repeat — must not emit twice for the same status

    expect(emitted, [ConnectivityStatus.offline]);
  });
}
