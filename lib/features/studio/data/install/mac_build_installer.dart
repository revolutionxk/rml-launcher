import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/download/downloader.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install/install_progress.dart';
import 'package:rml_launcher/features/studio/data/install/staging_area.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';

final RegExp _md5 = RegExp(r'^[0-9a-f]{32}$');

String? md5FromEtag(String? etag) {
  if (etag == null ||
      etag.length < 2 ||
      !etag.startsWith('"') ||
      !etag.endsWith('"')) {
    return null;
  }
  final String bare = etag.substring(1, etag.length - 1).toLowerCase();
  return _md5.hasMatch(bare) ? bare : null;
}

final class MacBuildInstaller implements BuildInstaller {
  MacBuildInstaller({
    required this._cdn,
    required this._downloader,
    required this._native,
    required this._layout,
    required this._staging,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String binaryTarget = 'MacStudio';
  static const String archiveName = 'RobloxStudioApp.zip';

  final StudioCdn _cdn;
  final Downloader _downloader;
  final NativeService _native;
  final StudioLayout _layout;
  final StagingArea _staging;
  final DateTime Function() _clock;

  @override
  Future<Result<InstalledBuild>> install(
    BuildRequest request,
    TaskControl control,
  ) async {
    control.phase(TaskPhase.resolving);
    final Uri url = _cdn.macAppUrl(request.guid);
    final Result<RemoteFile> head = await _cdn.head(url);
    final RemoteFile? remote = head.valueOrNull;
    if (remote == null) {
      return Result<InstalledBuild>.err(head.failureOrNull!);
    }
    final String archive = p.join(
      _layout.downloadsDir(request.version),
      archiveName,
    );
    final int? size = remote.size;
    if (size != null) {
      final Result<void> space = _staging.ensureSpace(
        size * 4 - _bytesOnDisk(archive),
      );
      if (space.failureOrNull case final AppFailure failure) {
        return Result<InstalledBuild>.err(failure);
      }
    }
    final Result<String> prepared = await _staging.prepare(
      request.installId,
      request.version,
    );
    final String? staging = prepared.valueOrNull;
    if (staging == null) {
      return Result<InstalledBuild>.err(prepared.failureOrNull!);
    }
    final InstallProgress progress = InstallProgress(
      control,
      packed: size ?? 0,
      clock: _clock,
    );
    control.phase(TaskPhase.downloading);
    final Result<void> downloaded = await _downloader.download(
      DownloadRequest(
        url: url,
        path: archive,
        size: size,
        md5: md5FromEtag(remote.etag),
      ),
      abort: control.abort,
      onBytes: progress.downloaded,
    );
    if (downloaded.failureOrNull case final AppFailure failure) {
      return _fail(staging, failure);
    }
    control.phase(TaskPhase.extracting);
    final Result<ExtractedArchive> extracted = await _native.extractZip(
      archive,
      staging,
      onProgress: (int done, int total) =>
          progress.extracted(archiveName, done, total),
    );
    if (extracted.failureOrNull case final AppFailure failure) {
      return _fail(staging, failure);
    }
    if (control.abort.isAborted) {
      return _fail(staging, const CancelledFailure());
    }
    final File executable = File(
      p.join(
        staging,
        StudioLayout.appBundle,
        'Contents',
        'MacOS',
        'RobloxStudio',
      ),
    );
    if (!executable.existsSync()) {
      return _fail(staging, const NotFoundFailure(what: 'RobloxStudio.app'));
    }
    control.phase(TaskPhase.finalizing);
    try {
      await File(p.join(staging, 'version.txt'))
          .writeAsString(request.version.text, flush: true);
      await File(p.join(staging, 'version-guid.txt'))
          .writeAsString(request.guid, flush: true);
    } on FileSystemException catch (error, stackTrace) {
      return _fail(
        staging,
        IoFailure(path: staging, cause: error, stackTrace: stackTrace),
      );
    }
    final Result<InstalledBuild> committed = await _staging.commit(
      installId: request.installId,
      staging: staging,
      marker: BuildMarker(
        version: request.version,
        guid: request.guid,
        binaryTarget: binaryTarget,
        installedAt: _clock(),
        publishedAt: request.publishedAt,
      ),
    );
    if (committed.isErr) {
      await _staging.discard(staging);
    } else {
      progress.finish();
    }
    return committed;
  }

  Future<Result<InstalledBuild>> _fail(
    String staging,
    AppFailure failure,
  ) async {
    await _staging.discard(staging);
    return Result<InstalledBuild>.err(failure);
  }

  static int _bytesOnDisk(String archive) {
    final File done = File(archive);
    final File partial = File('$archive.partial');
    if (done.existsSync()) {
      return done.lengthSync();
    }
    return partial.existsSync() ? partial.lengthSync() : 0;
  }
}
