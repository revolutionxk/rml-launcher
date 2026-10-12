import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/net/http.dart';
import 'package:rml_launcher/core/net/retry.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/cdn/deploy_history.dart';
import 'package:rml_launcher/features/studio/data/cdn/package_manifest.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

import '../../../../support/fixture_server.dart';

const RetryPolicy fast = RetryPolicy(<Duration>[
  Duration.zero,
  Duration.zero,
  Duration.zero,
  Duration.zero,
]);

const String history =
    'New Studio64 version-a at 4/14/2026 10:05:34 AM, file version: 0, 717, 0, 7170978, git hash: 0.717.0.7170978 ...\n'
    'New Studio64 version-b at 4/15/2026 10:08:30 AM, file version: 0, 717, 0, 7170982, git hash: 0.717.0.7170982 ...\n'
    'New Studio64 version-c at 4/21/2026 1:46:52 PM, file version: 0, 718, 0, 7181104, git hash: 0.718.0.7181104 ...\n';

void main() {
  late FixtureServer server;
  late HttpClient client;

  setUp(() async {
    server = await FixtureServer.start();
    client = createHttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  RobloxCdn cdn(CdnPlatform platform) => RobloxCdn(
    client: client,
    platform: platform,
    endpoints: CdnEndpoints.local(server.base),
    retry: fast,
    readTimeout: const Duration(milliseconds: 300),
  );

  void live(String target, String version, String guid) => server.serveText(
    'client-version/$target/channel/LIVE',
    jsonEncode(<String, Object?>{
      'version': version,
      'clientVersionUpload': guid,
    }),
  );

  test('the platform follows the host and cpu', () {
    expect(
      CdnPlatform.forHost(HostOs.windows, Abi.windowsX64),
      CdnPlatform.windows,
    );
    expect(
      CdnPlatform.forHost(HostOs.macos, Abi.macosArm64),
      CdnPlatform.macArm64,
    );
    expect(CdnPlatform.forHost(HostOs.macos, Abi.macosX64), CdnPlatform.macX64);
    expect(CdnPlatform.forHost(HostOs.linux, Abi.linuxX64), isNull);
    expect(CdnPlatform.windows.binaryTarget, 'WindowsStudio64');
    expect(CdnPlatform.macArm64.product, 'Studio');
  });

  test('reads the live version', () async {
    live('WindowsStudio64', '0.718.0.7181104', 'version-c');
    final Result<LiveVersion> result = await cdn(CdnPlatform.windows)
        .liveVersion();
    expect(result.valueOrNull!.version.text, '0.718.0.7181104');
    expect(result.valueOrNull!.guid, 'version-c');
  });

  test('an unexpected live response is a validation failure', () async {
    server.serveText('client-version/MacStudio/channel/LIVE', '[]');
    final Result<LiveVersion> result = await cdn(CdnPlatform.macArm64)
        .liveVersion();
    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('reads the deploy history from the platform folder', () async {
    server.serveText(
      'setup/mac/arm64/DeployHistory.txt',
      history.replaceAll('Studio64', 'Studio'),
    );
    final Result<List<DeployedBuild>> result = await cdn(CdnPlatform.macArm64)
        .deployHistory();
    expect(result.valueOrNull, hasLength(3));
  });

  test('resolves a guid from live first, then the ledger', () async {
    live('WindowsStudio64', '0.718.0.7181104', 'version-c');
    server.serveText(
      'ledger.json',
      jsonEncode(<String, String>{'0.717.0.7170982': 'version-b'}),
    );
    final RobloxCdn windows = cdn(CdnPlatform.windows);
    expect(
      (await windows.resolveGuid(StudioVersion.parse('0.718.0.7181104')))
          .valueOrNull,
      'version-c',
    );
    expect(
      (await windows.resolveGuid(StudioVersion.parse('0.717.0.7170982')))
          .valueOrNull,
      'version-b',
    );
    expect(
      (await windows.resolveGuid(StudioVersion.parse('0.600.0.1')))
          .failureOrNull,
      isA<UnsupportedFailure>(),
    );
    expect(server.hits('ledger.json'), 1);
  });

  test('macos resolves only the live build', () async {
    live('MacStudio', '0.718.0.7181104', 'version-c');
    final Result<String> result = await cdn(CdnPlatform.macArm64)
        .resolveGuid(StudioVersion.parse('0.717.0.7170982'));
    expect(result.failureOrNull, isA<UnsupportedFailure>());
  });

  test(
    'available builds drop versions the ledger lacks unless kept or live',
    () async {
      server
        ..serveText('setup/DeployHistory.txt', history)
        ..serveText(
          'ledger.json',
          jsonEncode(<String, String>{'0.717.0.7170982': 'version-b'}),
        );
      live('WindowsStudio64', '0.718.0.7181104', 'version-c');
      final Result<List<DeployedBuild>> result = await cdn(CdnPlatform.windows)
          .availableBuilds(
            keep: <StudioVersion>{StudioVersion.parse('0.717.0.7170978')},
          );
      expect(
        result.valueOrNull!.map((DeployedBuild build) => build.version.text),
        <String>['0.718.0.7181104', '0.717.0.7170982', '0.717.0.7170978'],
      );
    },
  );

  test('available builds keep everything when the ledger fails', () async {
    server.serveText('setup/DeployHistory.txt', history);
    live('WindowsStudio64', '0.718.0.7181104', 'version-c');
    final Result<List<DeployedBuild>> result = await cdn(CdnPlatform.windows)
        .availableBuilds();
    expect(result.valueOrNull, hasLength(3));
  });

  test('reads a package manifest and builds package urls', () async {
    server.serveText(
      'setup/version-c-rbxPkgManifest.txt',
      'v0\nRobloxApp.zip\nabc\n1\n2\n',
    );
    final RobloxCdn windows = cdn(CdnPlatform.windows);
    final Result<List<PackageEntry>> result = await windows.packageManifest(
      'version-c',
    );
    expect(result.valueOrNull!.single.name, 'RobloxApp.zip');
    expect(
      windows.packageUrl('version-c', 'RobloxApp.zip'),
      server.base.resolve('setup/version-c-RobloxApp.zip'),
    );
    expect(
      cdn(CdnPlatform.macX64).macAppUrl('version-c'),
      server.base.resolve('setup/mac/version-c-RobloxStudioApp.zip'),
    );
  });

  test('retries a server error, then succeeds', () async {
    server
      ..serveText('setup/DeployHistory.txt', history)
      ..fault('setup/DeployHistory.txt', const StatusFault(503))
      ..fault('setup/DeployHistory.txt', const StatusFault(429));
    final Result<List<DeployedBuild>> result = await cdn(CdnPlatform.windows)
        .deployHistory();
    expect(result.valueOrNull, hasLength(3));
    expect(server.hits('setup/DeployHistory.txt'), 3);
  });

  test('a missing file fails at once', () async {
    final Result<List<PackageEntry>> result = await cdn(CdnPlatform.windows)
        .packageManifest('version-missing');
    expect(
      result.failureOrNull,
      isA<NetworkFailure>().having(
        (NetworkFailure failure) => failure.statusCode,
        'status',
        404,
      ),
    );
    expect(server.hits('setup/version-missing-rbxPkgManifest.txt'), 1);
  });

  test('a stalled response times out', () async {
    server.serveText('setup/DeployHistory.txt', history);
    for (int attempt = 0; attempt < 5; attempt++) {
      server.fault('setup/DeployHistory.txt', const StallFault(10));
    }
    final Result<List<DeployedBuild>> result = await cdn(CdnPlatform.windows)
        .deployHistory();
    expect(
      result.failureOrNull,
      isA<NetworkFailure>().having(
        (NetworkFailure failure) => failure.isTimeout,
        'timeout',
        isTrue,
      ),
    );
  });

  test('head reads the size and etag', () async {
    server.serve(
      'setup/mac/arm64/version-c-RobloxStudioApp.zip',
      List<int>.filled(42, 1),
      headers: <String, String>{'etag': '"0123456789abcdef0123456789abcdef"'},
    );
    final RobloxCdn mac = cdn(CdnPlatform.macArm64);
    final Result<RemoteFile> result = await mac.head(
      mac.macAppUrl('version-c'),
    );
    expect(result.valueOrNull!.size, 42);
    expect(result.valueOrNull!.etag, '"0123456789abcdef0123456789abcdef"');
  });

  test('a non-200 response whose body stalls times out', () async {
    server.serveText('setup/DeployHistory.txt', history);
    for (int attempt = 0; attempt < 5; attempt++) {
      server.fault('setup/DeployHistory.txt', const StatusStallFault(503));
    }
    final Result<List<DeployedBuild>> result = await cdn(CdnPlatform.windows)
        .deployHistory();
    expect(
      result.failureOrNull,
      isA<NetworkFailure>().having(
        (NetworkFailure failure) => failure.isTimeout,
        'timeout',
        isTrue,
      ),
    );
    expect(server.hits('setup/DeployHistory.txt'), 5);
  });

  test('a stalled head times out', () async {
    const String path = 'setup/mac/arm64/version-c-RobloxStudioApp.zip';
    server.serve(path, List<int>.filled(42, 1));
    for (int attempt = 0; attempt < 5; attempt++) {
      server.fault(path, const HeaderStallFault());
    }
    final RobloxCdn mac = cdn(CdnPlatform.macArm64);
    final Result<RemoteFile> result = await mac.head(
      mac.macAppUrl('version-c'),
    );
    expect(
      result.failureOrNull,
      isA<NetworkFailure>().having(
        (NetworkFailure failure) => failure.isTimeout,
        'timeout',
        isTrue,
      ),
    );
  });

  test('a malformed body is a network failure', () async {
    server.serve('setup/DeployHistory.txt', <int>[0xff, 0xfe, 0xfd]);
    final Result<List<DeployedBuild>> result = await cdn(CdnPlatform.windows)
        .deployHistory();
    expect(result.failureOrNull, isA<NetworkFailure>());
  });

  test('macos surfaces a failed live lookup', () async {
    final Result<String> result = await cdn(CdnPlatform.macArm64)
        .resolveGuid(StudioVersion.parse('0.717.0.7170982'));
    expect(result.failureOrNull, isA<NetworkFailure>());
  });
}
