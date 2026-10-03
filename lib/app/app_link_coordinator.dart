class AppLinkCoordinator {
  AppLinkCoordinator({
    required Future<void> Function(String raw) handleOpenDayQr,
    required void Function(String route) navigate,
  }) : _handleOpenDayQr = handleOpenDayQr,
       _navigate = navigate;

  final Future<void> Function(String raw) _handleOpenDayQr;
  final void Function(String route) _navigate;

  Future<void> handle(Uri uri) async {
    if (uri.scheme == 'io.mqjourney' && uri.host == 'open-day') {
      await _handleOpenDayQr(uri.toString());
      return;
    }
    if (uri.host != 'meet' ||
        (uri.scheme != 'io.mqjourney' && uri.scheme != 'io.mqnavigation')) {
      return;
    }
    final latitude = double.tryParse(uri.queryParameters['lat'] ?? '');
    final longitude = double.tryParse(uri.queryParameters['lng'] ?? '');
    if (latitude == null || longitude == null) return;
    _navigate('/meet?lat=$latitude&lng=$longitude');
  }
}
