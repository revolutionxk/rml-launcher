import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/discovery/discovery_provider.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';
import 'package:rml_launcher/features/studio/services/discovery_service.dart';
import 'package:rml_launcher/features/studio/services/studio_lifecycle.dart';
import 'package:rml_launcher/features/studio/services/update_service.dart';

import '../../../support/service_harness.dart';
import '../../../support/studio_fixtures.dart';

final class CountingProvider implements DiscoveryProvider {
  int scans = 0;

  @override
  Set<InstallSource> get sources => const <InstallSource>{InstallSource.roblox};

  @override
  Future<DiscoveryScan> scan() async {
    scans++;
    return const DiscoveryScan();
  }
}

void main() {
  late ServiceHarness harness;
  late CountingProvider provider;
  late UpdateService updates;
  late StudioLifecycle lifecycle;
  DateTime now = DateTime.utc(2026, 10, 12, 9);

  setUp(() async {
    harness = await ServiceHarness.start();
    harness.cdn.live = LiveVersion(
      version: StudioVersion.parse('0.690.0.1'),
      guid: 'version-live',
    );
    provider = CountingProvider();
    now = DateTime.utc(2026, 10, 12, 9);
    updates = harness.updateService(clock: () => now);
    lifecycle = StudioLifecycle(
      layout: harness.layout,
      discovery: DiscoveryService(
        library: harness.library,
        providers: <DiscoveryProvider>[provider],
        layout: harness.layout,
        events: harness.events,
      ),
      updates: updates,
      running: harness.running,
    );
  });

  tearDown(() async {
    await lifecycle.dispose();
    await harness.close();
  });

  String builds(String name) => p.join(harness.layout.buildsDir('main'), name);

  test('start clears leftovers, scans and checks for updates', () async {
    Directory(builds('.0.691.0.1.staging')).createSync(recursive: true);
    Directory(builds('.0.690.0.1.replaced')).createSync(recursive: true);
    File(p.join(builds('.0.690.0.1.replaced'), 'old.txt'))
        .writeAsStringSync('old');
    File(p.join(builds('0.690.0.1'), 'new.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('new');
    final File partial = File(
      p.join(
        harness.layout.root,
        '.downloads',
        '0.691.0.1',
        'RobloxApp.zip.partial',
      ),
    )..createSync(recursive: true);
    await lifecycle.start();
    expect(Directory(builds('.0.691.0.1.staging')).existsSync(), isFalse);
    expect(Directory(builds('.0.690.0.1.replaced')).existsSync(), isFalse);
    expect(File(p.join(builds('0.690.0.1'), 'new.txt')).existsSync(), isTrue);
    expect(File(p.join(builds('0.690.0.1'), 'old.txt')).existsSync(), isFalse);
    expect(partial.existsSync(), isTrue);
    expect(provider.scans, 1);
    await until(() => harness.cdn.liveRequests == 1);
  });

  test('focus rescans and checks only when a check is due', () async {
    await lifecycle.start();
    await until(() => harness.cdn.liveRequests == 1);
    await lifecycle.onFocus();
    expect(provider.scans, 2);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(harness.cdn.liveRequests, 1);
    now = now.add(const Duration(minutes: 20));
    await lifecycle.onFocus();
    await until(() => harness.cdn.liveRequests == 2);
  });

  test(
    'start restores a replaced build left by an interrupted commit',
    () async {
      final File kept = File(
        p.join(builds('.0.690.0.1.replaced'), 'RobloxStudioBeta.exe'),
      )..createSync(recursive: true);
      kept.writeAsStringSync('old');
      await lifecycle.start();
      expect(Directory(builds('.0.690.0.1.replaced')).existsSync(), isFalse);
      expect(
        File(p.join(builds('0.690.0.1'), 'RobloxStudioBeta.exe'))
            .readAsStringSync(),
        'old',
      );
    },
  );

  test('start carries on when an install folder cannot be listed', () async {
    final String locked = harness.layout.buildsDir('locked');
    Directory(p.join(locked, '.0.1.0.0.staging')).createSync(recursive: true);
    Directory(builds('.0.691.0.1.staging')).createSync(recursive: true);
    Process.runSync('chmod', <String>['000', locked]);
    addTearDown(() => Process.runSync('chmod', <String>['755', locked]));
    await lifecycle.start();
    expect(Directory(builds('.0.691.0.1.staging')).existsSync(), isFalse);
    expect(provider.scans, 1);
    await until(() => harness.cdn.liveRequests == 1);
  }, skip: Platform.isWindows);

  test('visibility changes the polling interval', () async {
    await lifecycle.start();
    lifecycle.setVisible(visible: false);
    expect(harness.running.interval, const Duration(seconds: 10));
  });
}
