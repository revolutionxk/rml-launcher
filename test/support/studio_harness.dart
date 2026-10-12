import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/net/http.dart';
import 'package:rml_launcher/core/net/retry.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/activity_repository.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/download/download_limiter.dart';
import 'package:rml_launcher/features/studio/data/download/downloader.dart';
import 'package:rml_launcher/features/studio/data/install/staging_area.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';

import 'fake_native_service.dart';
import 'fixture_server.dart';
import 'memory_json_store.dart';

const RetryPolicy fastRetry = RetryPolicy(<Duration>[
  Duration.zero,
  Duration.zero,
  Duration.zero,
  Duration.zero,
]);

final class StudioHarness {
  StudioHarness._({
    required this.server,
    required this.client,
    required this.dir,
    required this.layout,
    required this.tasks,
    required this.native,
  });

  static Future<StudioHarness> start({required HostOs os}) async {
    final FixtureServer server = await FixtureServer.start();
    final Directory dir = await Directory.systemTemp.createTemp(
      'rml studio Ação ',
    );
    return StudioHarness._(
      server: server,
      client: createHttpClient(),
      dir: dir,
      layout: StudioLayout(root: p.join(dir.path, 'Studio'), os: os),
      tasks: TaskCenter(history: ActivityRepository(MemoryJsonStore())),
      native: FakeNativeService(realFiles: true),
    );
  }

  final FixtureServer server;
  final HttpClient client;
  final Directory dir;
  final StudioLayout layout;
  final TaskCenter tasks;
  final FakeNativeService native;

  RobloxCdn cdn(CdnPlatform platform) => RobloxCdn(
    client: client,
    platform: platform,
    endpoints: CdnEndpoints.local(server.base),
    retry: fastRetry,
  );

  Downloader downloader() => Downloader(
    client: client,
    native: native,
    limiter: DownloadLimiter(4),
    retry: fastRetry,
  );

  StagingArea staging() => StagingArea(layout: layout, native: native);

  Future<Result<T>> runInstall<T>(String installId, TaskJob<T> job) => tasks
      .run<T>(TaskRequest(kind: TaskKind.install, installId: installId), job);

  Future<void> close() async {
    client.close(force: true);
    await server.close();
    await dir.delete(recursive: true);
  }
}
