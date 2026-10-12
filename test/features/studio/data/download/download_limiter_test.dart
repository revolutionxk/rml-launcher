import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/features/studio/data/download/download_limiter.dart';

void main() {
  test('never runs more than the slots at once', () async {
    final DownloadLimiter limiter = DownloadLimiter(2);
    int running = 0;
    int peak = 0;
    final List<Completer<void>> gates = List<Completer<void>>.generate(
      6,
      (_) => Completer<void>(),
    );
    final List<Future<int>> jobs = <Future<int>>[
      for (int index = 0; index < 6; index++)
        limiter.run(() async {
          running++;
          peak = running > peak ? running : peak;
          await gates[index].future;
          running--;
          return index;
        }),
    ];
    for (final Completer<void> gate in gates) {
      await Future<void>.delayed(Duration.zero);
      gate.complete();
    }
    expect(await Future.wait(jobs), <int>[0, 1, 2, 3, 4, 5]);
    expect(peak, 2);
  });

  test('a failing body frees its slot', () async {
    final DownloadLimiter limiter = DownloadLimiter(1);
    await expectLater(
      limiter.run<void>(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await limiter.run(() async => 1), 1);
  });
}
