import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/data/adapters/settings_progress_api_adapter.dart';
import 'package:mq_journey/features/scan/domain/contracts/progress_api.dart';
import 'package:mq_journey/features/scan/domain/contracts/visit_event.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/features/scan/providers/scan_providers.dart';

void main() {
  test('visited state releases its source stream when unobserved', () async {
    final progress = _CountingProgressApi();
    addTearDown(progress.close);
    final container = ProviderContainer(
      overrides: [progressApiProvider.overrideWithValue(progress)],
    );
    addTearDown(container.dispose);

    final provider = visitedStateProvider('C3A');
    final subscription = container.listen(provider, (_, _) {});
    await container.read(provider.future);

    subscription.close();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(progress.cancelCount, 1);
  });
}

class _CountingProgressApi implements ProgressApi {
  _CountingProgressApi() {
    _controller = StreamController<VisitedState>.broadcast(
      onListen: () {
        _controller.add(
          const VisitedState(visited: false, rewardEarned: false),
        );
      },
      onCancel: () => cancelCount += 1,
    );
  }

  late final StreamController<VisitedState> _controller;
  int cancelCount = 0;

  @override
  Future<bool> recordVisit(VisitEvent event) async => false;

  @override
  Stream<VisitedState> watch(String locationId) => _controller.stream;

  Future<void> close() => _controller.close();
}
