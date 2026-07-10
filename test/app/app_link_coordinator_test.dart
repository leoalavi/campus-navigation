import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/app_link_coordinator.dart';

void main() {
  test('signed Open Day links use the verified QR ingress only', () async {
    final qrLinks = <String>[];
    final meetRoutes = <String>[];
    final coordinator = AppLinkCoordinator(
      handleOpenDayQr: (raw) async => qrLinks.add(raw),
      navigate: meetRoutes.add,
    );
    final uri = Uri.parse(
      'io.mqjourney://open-day/location/wallys-1?v=1&kid=key&sig=value',
    );

    await coordinator.handle(uri);

    expect(qrLinks, [uri.toString()]);
    expect(meetRoutes, isEmpty);
  });

  test('meet links retain validated coordinate routing', () async {
    final routes = <String>[];
    final coordinator = AppLinkCoordinator(
      handleOpenDayQr: (_) async {},
      navigate: routes.add,
    );

    await coordinator.handle(
      Uri.parse('io.mqjourney://meet?lat=-33.7&lng=151.1'),
    );
    await coordinator.handle(Uri.parse('io.mqjourney://meet?lat=x&lng=151.1'));

    expect(routes, ['/meet?lat=-33.7&lng=151.1']);
  });
}
