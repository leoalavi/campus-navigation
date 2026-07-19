import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/map/data/services/offline_maps_service.dart';

void main() {
  test('offline download lazily attempts backend initialization', () async {
    final service = _UnavailableOfflineMapsService();

    final completed = await service.downloadCampusTiles();

    expect(completed, isFalse);
    expect(service.initializeCallCount, 1);
  });
}

class _UnavailableOfflineMapsService extends OfflineMapsService {
  int initializeCallCount = 0;

  @override
  bool get isFmtcBackendReady => false;

  @override
  Future<void> initializeBackend() async {
    initializeCallCount += 1;
  }
}
