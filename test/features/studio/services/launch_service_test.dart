import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/discovery/vinegar.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/launch_service.dart';

import '../../../support/fake_process_starter.dart';
import '../../../support/service_harness.dart';
import '../../../support/studio_fixtures.dart';
import '../../../support/studio_library_fixtures.dart';

void main() {
  late ServiceHarness harness;
  late FakeProcessStarter processes;
  late LaunchService launcher;
  late StudioBuild build;

  Future<void> start(
    HostOs os, {
    Map<String, String> environment = const <String, String>{},
  }) async {
    harness = await ServiceHarness.start(os: os);
    processes = FakeProcessStarter();
    build = await harness.makeBuild('main', '0.690.0.1');
    await harness.library.update(
      (StudioLibrary library) =>
          library.upsert(managedInstall('main', current: build)),
    );
    launcher = harness.launchService(processes, environment: environment);
  }

  tearDown(() => harness.close());

  StartedProcess started() => processes.started.single;

  test(
    'windows starts studio from its folder and records the launch',
    () async {
      await start(HostOs.windows);
      expect((await launcher.launch('main')).isOk, isTrue);
      expect(started().executable, p.join(build.path, 'RobloxStudioBeta.exe'));
      expect(started().arguments, isEmpty);
      expect(started().workingDirectory, build.path);
      expect(harness.library.value.byId('main')!.lastLaunchedAt, isNotNull);
      expect(harness.tasks.tasks, isEmpty);
    },
  );

  test('a link goes through the launcher when there is one', () async {
    await start(HostOs.windows);
    File(p.join(build.path, 'RobloxStudioLauncherBeta.exe'))
        .writeAsStringSync('l');
    await launcher.launch('main', uri: 'roblox-studio:1+launchmode:edit');
    expect(
      started().executable,
      p.join(build.path, 'RobloxStudioLauncherBeta.exe'),
    );
    expect(started().arguments, <String>['roblox-studio:1+launchmode:edit']);
  });

  test('a link without a launcher goes to studio', () async {
    await start(HostOs.windows);
    await launcher.launch('main', uri: 'roblox-studio:1');
    expect(started().executable, p.join(build.path, 'RobloxStudioBeta.exe'));
    expect(started().arguments, <String>['roblox-studio:1']);
  });

  test('a missing executable is reported and nothing starts', () async {
    await start(HostOs.windows);
    File(p.join(build.path, 'RobloxStudioBeta.exe')).deleteSync();
    final Result<void> result = await launcher.launch('main');
    expect(
      result.failureOrNull,
      isA<NotFoundFailure>().having(
        (NotFoundFailure failure) => failure.what,
        'what',
        'Studio',
      ),
    );
    expect(processes.started, isEmpty);
  });

  test('macos opens another window of the bundle', () async {
    await start(HostOs.macos);
    await launcher.launch('main', uri: 'roblox-studio:1');
    expect(started().executable, 'open');
    expect(started().arguments, <String>[
      '-n',
      '-a',
      build.path,
      'roblox-studio:1',
    ]);
  });

  test('linux goes through the vinegar binary or the flatpak', () async {
    final Directory bin = await Directory.systemTemp.createTemp('rml bin ');
    addTearDown(() => bin.delete(recursive: true));
    File(p.join(bin.path, 'vinegar')).writeAsStringSync('');
    await start(HostOs.linux, environment: <String, String>{'PATH': bin.path});
    await harness.library.update(
      (StudioLibrary library) => library.upsert(
        foundInstall(
          'vinegar-1',
          InstallSource.vinegar,
          current: buildAt('/v'),
        ),
      ),
    );
    await launcher.launch('vinegar-1');
    expect(started().executable, 'vinegar');
    processes.started.clear();
    launcher = harness.launchService(processes);
    processes.outputs['flatpak info ${VinegarLocator.flatpakId}'] =
        const ProcessOutput(exitCode: 0);
    await launcher.launch('vinegar-1');
    expect(started().arguments, <String>['run', VinegarLocator.flatpakId]);
  });

  test('linux without vinegar says so', () async {
    await start(HostOs.linux);
    final Result<void> result = await launcher.launch('main');
    expect(
      result.failureOrNull,
      isA<NotFoundFailure>().having(
        (NotFoundFailure failure) => failure.what,
        'what',
        'Vinegar',
      ),
    );
  });

  test('a failing pre-launch hook stops the launch', () async {
    await start(HostOs.windows);
    harness.hooks.preLaunch.add(
      (StudioInstall install) async =>
          const Result<void>.err(ValidationFailure(message: 'loader broken')),
    );
    final Result<void> result = await launcher.launch('main');
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(processes.started, isEmpty);
  });

  test('a ready update can be applied right before launching', () async {
    await start(HostOs.windows);
    harness.cdn.live = LiveVersion(
      version: StudioVersion.parse('0.691.0.1'),
      guid: 'version-691',
    );
    await harness.updateService().checkForUpdates();
    final StudioBuild ready = harness.library.value.byId('main')!.ready!;
    await launcher.launch('main', applyReadyFirst: true);
    expect(started().workingDirectory, ready.path);
  });

  test('launching works while an update downloads', () async {
    await start(HostOs.windows);
    harness.cdn.live = LiveVersion(
      version: StudioVersion.parse('0.691.0.1'),
      guid: 'version-691',
    );
    harness.installer.gate = Completer<void>();
    final Future<Result<void>> updating = harness
        .updateService()
        .checkForUpdates();
    await until(() => harness.tasks.isBusy('main'));
    expect((await launcher.launch('main')).isOk, isTrue);
    harness.installer.gate!.complete();
    await updating;
  });

  test('an unknown install is not found', () async {
    await start(HostOs.windows);
    expect(
      (await launcher.launch('missing')).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('a launch while files are being checked is refused', () async {
    await start(HostOs.windows);
    final Completer<void> open = Completer<void>();
    final Future<Result<void>> checking = harness.tasks.run<void>(
      const TaskRequest(kind: TaskKind.checkFiles, installId: 'main'),
      (TaskControl control) async {
        await open.future;
        return const Result<void>.ok(null);
      },
    );
    final Result<void> result = await launcher.launch('main');
    expect(result.failureOrNull, isA<TaskBusyFailure>());
    expect(processes.started, isEmpty);
    open.complete();
    await checking;
  });

  test('a launch while an update is being applied is refused', () async {
    await start(HostOs.windows);
    final Completer<void> open = Completer<void>();
    final Future<Result<void>> applying = harness.tasks.run<void>(
      const TaskRequest(kind: TaskKind.applyUpdate, installId: 'main'),
      (TaskControl control) async {
        await open.future;
        return const Result<void>.ok(null);
      },
    );
    final Result<void> result = await launcher.launch('main');
    expect(result.failureOrNull, isA<TaskBusyFailure>());
    expect(processes.started, isEmpty);
    open.complete();
    await applying;
  });

  test('a swap during a pre-launch hook launches the new build', () async {
    await start(HostOs.windows);
    final StudioBuild swapped = await harness.makeBuild('main', '0.691.0.1');
    final Completer<void> open = Completer<void>();
    harness.hooks.preLaunch.add((StudioInstall install) async {
      await open.future;
      return const Result<void>.ok(null);
    });
    final Future<Result<void>> launching = launcher.launch('main');
    await until(() => harness.tasks.tasks.isNotEmpty);
    await harness.library.update(
      (StudioLibrary library) =>
          library.upsert(managedInstall('main', current: swapped)),
    );
    open.complete();
    expect((await launching).isOk, isTrue);
    expect(started().workingDirectory, swapped.path);
  });

  test('a pinned install keeps its build when asked to apply first', () async {
    await start(HostOs.windows);
    final StudioBuild ready = await harness.makeBuild('main', '0.691.0.1');
    await harness.library.update(
      (StudioLibrary library) => library.upsert(
        managedInstall(
          'main',
          current: build,
          ready: ready,
          policy: UpdatePolicy.pinned,
        ),
      ),
    );
    await launcher.launch('main', applyReadyFirst: true);
    expect(started().workingDirectory, build.path);
    expect(harness.library.value.byId('main')!.ready, isNotNull);
  });
}
