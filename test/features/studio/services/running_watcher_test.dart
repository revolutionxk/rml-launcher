import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/domain/running_studio.dart';
import 'package:rml_launcher/features/studio/domain/studio_event.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';

import '../../../support/fake_native_service.dart';
import '../../../support/studio_library_fixtures.dart';

void main() {
  late FakeNativeService native;
  late StudioEvents events;
  late List<StudioEvent> seen;

  setUp(() {
    native = FakeNativeService();
    events = StudioEvents();
    seen = <StudioEvent>[];
    events.stream.listen(seen.add);
  });

  tearDown(() => events.close());

  Future<RunningWatcher> watcher(HostOs os) async {
    final LibraryStore library = await libraryWith(<StudioInstall>[
      managedInstall(
        'main',
        current: buildAt('/s/main/builds/0.691.0.1', version: '0.691.0.1'),
        previous: buildAt('/s/main/builds/0.690.0.1'),
      ),
      foundInstall(
        'roblox-1',
        InstallSource.roblox,
        current: buildAt('/r/Versions/version-abc'),
      ),
      foundInstall('vinegar-1', InstallSource.vinegar),
    ]);
    DateTime now = DateTime.utc(2026, 10, 12, 9);
    return RunningWatcher(
      native: native,
      library: library,
      os: os,
      events: events,
      clock: () => now = now.add(const Duration(seconds: 1)),
    );
  }

  test('processes map to the install that holds them', () async {
    final RunningWatcher running = await watcher(HostOs.macos);
    native.processes = const <NativeProcess>[
      NativeProcess(
        pid: 1,
        path: '/s/main/builds/0.691.0.1/RobloxStudioBeta.exe',
      ),
      NativeProcess(
        pid: 2,
        path: '/s/main/builds/0.690.0.1/RobloxStudioBeta.exe',
      ),
      NativeProcess(
        pid: 3,
        path: '/r/Versions/version-abc/RobloxStudioBeta.exe',
      ),
      NativeProcess(pid: 4, path: '/elsewhere/RobloxStudioBeta.exe'),
    ];
    final List<RunningStudio> found = running.poll();
    expect(found.map((RunningStudio studio) => studio.installId), <String?>[
      'main',
      'main',
      'roblox-1',
      null,
    ]);
    expect(running.isRunning('main'), isTrue);
    expect(running.isRunning('vinegar-1'), isFalse);
  });

  test('a failed listing counts as running', () async {
    final RunningWatcher running = await watcher(HostOs.windows);
    native.processes = const <NativeProcess>[
      NativeProcess(
        pid: 3,
        path: '/r/Versions/version-abc/RobloxStudioBeta.exe',
      ),
    ];
    expect(running.isRunning('main'), isFalse);
    native.processFailure = const NativeFailure(code: 5, message: 'denied');
    expect(running.isRunning('main'), isTrue);
    expect(running.isRunning('vinegar-1'), isTrue);
    expect(running.poll().single.installId, 'roblox-1');
  });

  test('windows paths match without case', () async {
    final RunningWatcher running = await watcher(HostOs.windows);
    native.processes = const <NativeProcess>[
      NativeProcess(
        pid: 1,
        path: '/S/Main/Builds/0.691.0.1/RobloxStudioBeta.EXE',
      ),
    ];
    expect(running.poll().single.installId, 'main');
  });

  test('linux processes belong to the vinegar install', () async {
    final RunningWatcher running = await watcher(HostOs.linux);
    native.processes = const <NativeProcess>[
      NativeProcess(pid: 9, path: r'C:\users\steamuser\RobloxStudioBeta.exe'),
    ];
    expect(running.poll().single.installId, 'vinegar-1');
  });

  test(
    'start and exit are announced once and keep the first seen time',
    () async {
      final RunningWatcher running = await watcher(HostOs.macos);
      native.processes = const <NativeProcess>[
        NativeProcess(pid: 1, path: '/s/main/builds/0.691.0.1/x'),
      ];
      final DateTime first = running.poll().single.startedAt;
      expect(running.poll().single.startedAt, first);
      native.processes = const <NativeProcess>[];
      running.poll();
      await Future<void>.delayed(Duration.zero);
      expect(seen.whereType<StudioStarted>(), hasLength(1));
      expect(seen.whereType<StudioExited>(), hasLength(1));
      expect(running.running, isEmpty);
    },
  );

  test('the polling interval follows visibility', () async {
    final RunningWatcher running = await watcher(HostOs.macos);
    expect(running.interval, const Duration(seconds: 2));
    running.setVisible(visible: false);
    expect(running.interval, const Duration(seconds: 10));
    running.setVisible(visible: true);
    expect(running.interval, const Duration(seconds: 2));
    await running.dispose();
  });

  test('close and force quit go to the native layer', () async {
    final RunningWatcher running = await watcher(HostOs.macos);
    native.processes = const <NativeProcess>[
      NativeProcess(pid: 7, path: '/s/main/builds/0.691.0.1/x'),
    ];
    running.poll();
    expect(running.close(7).isOk, isTrue);
    expect(native.closed, <int>[7]);
    expect(running.forceQuit(7).isOk, isTrue);
    expect(native.killed, <int>[7]);
    expect(running.running, isEmpty);
  });

  test('the executable name follows the os', () {
    expect(RunningWatcher.executableFor(HostOs.macos), 'RobloxStudio');
    expect(
      RunningWatcher.executableFor(HostOs.windows),
      'RobloxStudioBeta.exe',
    );
    expect(RunningWatcher.executableFor(HostOs.linux), 'RobloxStudioBeta.exe');
  });
}
